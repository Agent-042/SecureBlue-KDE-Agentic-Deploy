import os
from google import genai
from github import Github

print("[+] Dipping the brush... Activating Gemini to paint the BlueBuild recipe.")

# Initialize the Architect via the modern Google GenAI SDK
client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

# Craft the system prompt defining the OS architecture
prompt = """
You are the Lead OS Architect building a cutting-edge, declarative OCI image via BlueBuild.
The base image must be SecureBlue KDE for Nvidia (Fedora-based hardened atomic desktop).
Target Hardware: Intel Core Ultra 9 285H, NVIDIA GeForce RTX 5080, 32GB RAM.

Generate a flawless, production-ready 'recipe.yml' file incorporating:
1. Hardened Kernel Argument (kargs) Overrides for VFIO and Virtualization:
   - intel_iommu=on
   - iommu=pt
   - kvm.ignore_msrs=1
2. System Security Packages & Services:
   - Layer 'pcsc-lite' and 'pcsc-lite-ccid'
   - Enable the 'pcscd.service' for hardware YubiKey zero-trust authentication.
3. Performance & Virtualization Tooling:
   - Layer 'libvirt', 'qemu-kvm', and 'virt-manager' for Whonix KVM isolation.
4. Flatpak Applications (configured securely):
   - Include: com.google.Chrome, com.dropbox.Dropbox, org.keepassxc.KeePassXC

Output ONLY the raw contents of the recipe.yml file inside a single code block. Do not include any conversational preamble.
"""

try:
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
    )
    recipe_content = response.text
    
    # Clean up markdown code blocks if the model wrapped them
    if "```yaml" in recipe_content:
        recipe_content = recipe_content.split("```yaml")[1].split("```")[0].strip()
    elif "```" in recipe_content:
        recipe_content = recipe_content.split("```")[1].split("```")[0].strip()

    # Save locally first so the human can review the canvas
    os.makedirs("recipes", exist_ok=True)
    recipe_path = "recipes/recipe.yml"
    with open(recipe_path, "w") as f:
        f.write(recipe_content)
    print(f"[+] Recipe successfully painted and saved locally to: {recipe_path}")

except Exception as e:
    print(f"[-] Failed to generate recipe via Gemini: {e}")
    exit(1)

# Push the finalized canvas directly to the private GitHub repository
print("[+] Pushing the canvas to your private GitHub repository...")
g = Github(os.environ.get("GITHUB_PAT"))
repo = g.get_repo("Agent-042/SecureBlue-KDE-Agentic-Deploy")

try:
    # Check if the file already exists to update it, otherwise create it
    try:
        contents = repo.get_contents("recipes/recipe.yml", ref="main")
        repo.update_file(
            path="recipes/recipe.yml",
            message="agentic: optimize recipe for Core Ultra 9/RTX 5080 hardware stack",
            content=recipe_content,
            sha=contents.sha,
            branch="main"
        )
        print("[+] Success! Existing recipe.yml updated in GitHub.")
    except Exception:
        repo.create_file(
            path="recipes/recipe.yml",
            message="agentic: initialize declarative BlueBuild recipe",
            content=recipe_content,
            branch="main"
        )
        print("[+] Success! New recipe.yml created in GitHub.")

    print("\n=======================================================")
    print("MAGIC BUTTON ACTIVATED: Check the 'Actions' tab in your GitHub repo!")
    print("=======================================================\n")

except Exception as e:
    print(f"[-] Failed to push file to GitHub: {e}")
