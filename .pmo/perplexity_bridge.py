#!/usr/bin/env python3
# Perplexity Pro Deep Research Playwright Bridge
# Part of the PMO automated tooling framework.
#
# Usage:
#   perplexity_bridge.py --query "What are the latest developments in Fedora Silverblue?"
#   perplexity_bridge.py --daemon

import os
import sys
import json
import asyncio
import argparse
from datetime import datetime
from playwright.async_api import async_playwright

# Setup paths
PERSISTENT_CONTEXT_DIR = "/root/.config/playwright-perplexity-session"
QUEUE_DIR = "/root/Agentic-OS/perplexity_queue"
QUEUE_FILE = os.path.join(QUEUE_DIR, "queries.json")
RESULTS_DIR = os.path.join(QUEUE_DIR, "results")

os.makedirs(QUEUE_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

# Initialize Queue File if missing
if not os.path.exists(QUEUE_FILE):
    with open(QUEUE_FILE, "w") as f:
        json.dump([], f, indent=2)


async def setup_stealth(page):
    """Applies human-like attributes to prevent bot-detection flags."""
    await page.set_extra_http_headers({
        "Accept-Language": "en-US,en;q=0.9"
    })
    # Remove webdriver flag
    await page.add_init_script(
        "delete Object.getPrototypeOf(navigator).webdriver;"
    )


async def run_query(query_text, output_filename=None, headless=None):
    """Launches Playwright, navigates to Perplexity, inputs the query, and retrieves results."""
    if headless is None:
        headless = False if (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")) else True
    print(f"[{datetime.now().isoformat()}] Launching Playwright browser (headless={headless})...")
    async with async_playwright() as p:
        browser_args = [
            "--disable-blink-features=AutomationControlled",
            "--no-sandbox",
            "--disable-setuid-sandbox"
        ]
        if os.environ.get("WAYLAND_DISPLAY") and not headless:
            browser_args.extend([
                "--ozone-platform=wayland",
                "--enable-features=UseOzonePlatform"
            ])

        # Launch Chromium with persistent context to preserve login/cookies
        context = await p.chromium.launch_persistent_context(
            user_data_dir=PERSISTENT_CONTEXT_DIR,
            headless=headless,
            args=browser_args,
            viewport={"width": 1280, "height": 800}
        )

        page = context.pages[0] if context.pages else await context.new_page()
        await setup_stealth(page)

        print(f"[{datetime.now().isoformat()}] Navigating to Perplexity...")
        try:
            await page.goto("https://www.perplexity.ai", wait_until="domcontentloaded", timeout=45000)
        except Exception as e:
            print(f"Navigation error: {e}. Retrying with longer timeout...")
            await page.goto("https://www.perplexity.ai", wait_until="load", timeout=90000)

        # Check for Google login or recaptcha indicator
        if "login" in page.url or await page.locator("text=Sign in").count() > 0:
            print("\n" + "="*80)
            print("WARNING: USER SIGN-IN REQUIRED OR CAPTCHA ENCOUNTERED.")
            print(f"Please log in or solve captcha. Waiting up to 5 minutes...")
            print("="*80 + "\n")
            try:
                # Wait for user to sign in or bypass captcha
                await page.wait_for_selector("textarea", timeout=300000)
            except Exception:
                print("Timeout waiting for user interaction. Closing.")
                await context.close()
                return None

        # Locate main prompt textarea
        textarea_selector = "textarea[placeholder*='Ask anything'], textarea[placeholder*='Ask'], textarea"

        # Check for Turnstile/Cloudflare challenge page
        title = await page.title()
        if "Just a moment..." in title or "Cloudflare" in title or await page.locator("#challenge-error-text").count() > 0:
            print("\n" + "="*80)
            print("CLOUDFLARE TURNSTILE DETECTED ON USER DISPLAY!")
            print("Since this is the first boot, please click the Turnstile checkbox on your screen.")
            print("Waiting up to 5 minutes for verification to succeed...")
            print("="*80 + "\n")
            try:
                # Wait for the challenge to clear and the main textarea to become visible
                await page.wait_for_selector(textarea_selector, timeout=300000)
                print("Cloudflare Turnstile cleared successfully!")
            except Exception as e:
                print(f"Timeout/Error waiting for Cloudflare Turnstile to be solved: {e}")
                await context.close()
                return None

        print(f"[{datetime.now().isoformat()}] Entering query: '{query_text}'")
        try:
            await page.wait_for_selector(textarea_selector, timeout=30000)
        except Exception as e:
            debug_dir = "/root/Agentic-OS/perplexity_queue/debug"
            os.makedirs(debug_dir, exist_ok=True)
            screenshot_path = os.path.join(debug_dir, "timeout_screenshot.png")
            await page.screenshot(path=screenshot_path)
            html_path = os.path.join(debug_dir, "page_content.html")
            with open(html_path, "w") as f:
                f.write(await page.content())
            print(f"[{datetime.now().isoformat()}] Saved debug screenshot to {screenshot_path} and HTML to {html_path}")
            raise e
        
        # Click and type query with human-like delays
        await page.click(textarea_selector)
        for char in query_text:
            await page.type(textarea_selector, char, delay=35)
            
        # Select Deep Research (if toggle available)
        # Note: Perplexity's UI might vary; we click the focus/pro options if present
        pro_toggle = page.locator("button:has-text('Pro'), button[aria-label*='Pro']")
        if await pro_toggle.count() > 0:
            print("Pro/Deep Research option detected. Ensuring it is active...")
            # If toggle is off, click it
            if "bg-" not in (await pro_toggle.get_attribute("class") or ""):
                await pro_toggle.click()
                await asyncio.sleep(1)

        # Submit query
        print(f"[{datetime.now().isoformat()}] Submitting query...")
        await page.keyboard.press("Enter")

        # Wait for the search stream to begin and stabilize
        print(f"[{datetime.now().isoformat()}] Researching... (monitoring stream)...")
        await asyncio.sleep(5)

        # Wait until progress/thinking indicators disappear or the share button appears
        # Usually, once the text stops updating for 10 seconds, research is complete.
        last_length = 0
        stable_cycles = 0
        content_selector = "div.prose, [class*='answer'], div[class*='prose']"
        
        for i in range(120):  # Maximum 10 minutes wait
            await asyncio.sleep(5)
            content_elements = page.locator(content_selector)
            if await content_elements.count() > 0:
                text_content = await content_elements.first.inner_text()
                current_length = len(text_content)
                if current_length > 0 and current_length == last_length:
                    stable_cycles += 1
                else:
                    stable_cycles = 0
                last_length = current_length
                
                # If content length is identical for 3 cycles (15s) and length > 200, assume done
                if stable_cycles >= 3 and current_length > 200:
                    print(f"[{datetime.now().isoformat()}] Research stream completed successfully.")
                    break
            else:
                print("Waiting for content prose to generate...")

        # Extract structured content and citations
        content_elements = page.locator(content_selector)
        if await content_elements.count() > 0:
            md_content = await content_elements.first.inner_text()
            
            # Format results
            result_md = f"""# Perplexity Deep Research Result
**Query:** {query_text}
**Generated At:** {datetime.now().isoformat()}

---

## 📖 RESEARCH SYNTHESIS

{md_content}

---
*Generated via Antigravity Playwright Deep Research Bridge.*
"""
            # Save output
            if not output_filename:
                output_filename = f"research_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            
            result_path = os.path.join(RESULTS_DIR, output_filename)
            with open(result_path, "w") as f:
                f.write(result_md)
                
            print(f"[{datetime.now().isoformat()}] Saved deep research output to {result_path}")
            await context.close()
            return result_path
        else:
            print("Failed to capture research response content.")
            await context.close()
            return None


async def run_daemon():
    """Continuously monitors queries.json and processes pending deep research tasks."""
    print(f"[{datetime.now().isoformat()}] Perplexity Bridge Daemon started. Monitoring queue...")
    while True:
        try:
            if os.path.exists(QUEUE_FILE):
                with open(QUEUE_FILE, "r+") as f:
                    queries = json.load(f)
                    pending = [q for q in queries if q.get("status") == "pending"]
                    
                    if pending:
                        task = pending[0]
                        query_id = task.get("id")
                        query_text = task.get("query")
                        print(f"\nProcessing Task [{query_id}]: {query_text}")
                        
                        # Update task status to processing
                        task["status"] = "processing"
                        task["started_at"] = datetime.now().isoformat()
                        f.seek(0)
                        json.dump(queries, f, indent=2)
                        f.truncate()
                        
                        # Run query
                        out_file = f"task_{query_id}.md"
                        result_file = await run_query(query_text, output_filename=out_file)
                        
                        # Re-read and update status
                        f.seek(0)
                        queries = json.load(f)
                        task_updated = [q for q in queries if q.get("id") == query_id][0]
                        if result_file:
                            task_updated["status"] = "completed"
                            task_updated["result_file"] = result_file
                        else:
                            task_updated["status"] = "failed"
                        task_updated["completed_at"] = datetime.now().isoformat()
                        
                        f.seek(0)
                        json.dump(queries, f, indent=2)
                        f.truncate()
            
        except Exception as e:
            print(f"Daemon Loop Error: {e}")
            
        await asyncio.sleep(10)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Perplexity Pro Playwright Deep Research Bridge")
    parser.add_argument("--query", type=str, help="Execute a single deep research query")
    parser.add_argument("--daemon", action="store_true", help="Run in continuous queue daemon mode")
    
    args = parser.parse_args()
    
    if args.query:
        asyncio.run(run_query(args.query))
    elif args.daemon:
        asyncio.run(run_daemon())
    else:
        parser.print_help()
