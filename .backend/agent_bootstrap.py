import os
from github import Github

print("\n[+] Initializing SecureBlue KDE Agentic Pipeline...")

# Verify keys are loaded
github_pat = os.environ.get("GITHUB_PAT")
if not github_pat:
    raise ValueError("[-] GITHUB_PAT not found. Deployment halted.")

# Authenticate with GitHub
g = Github(github_pat)
try:
    user = g.get_user()
    print(f"[+] Successfully authenticated to GitHub as: {user.login}")
except Exception as e:
    print(f"[-] GitHub Authentication failed. Details: {e}")
    exit(1)

# Access your specific BlueBuild repository
repo_name = "Agent-042/SecureBlue-KDE-Agentic-Deploy"
try:
    repo = g.get_repo(repo_name)
    print(f"[+] Successfully connected to repository: {repo.full_name}")
    print("[+] Permissions validated. Ready to receive AI configurations.")
except Exception as e:
    print(f"[-] Error accessing repository '{repo_name}'. Check your PAT permissions. Details: {e}")
    exit(1)

print("\n=======================================================")
print("ENVIRONMENT READY: Your brushes and canvas are connected.")
print("=======================================================\n")
