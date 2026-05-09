import os
import re

path = "android/app/build.gradle"
alias = os.environ.get("KEY_ALIAS", "")
pw    = os.environ.get("KEY_PASSWORD", "")

with open(path) as f:
    txt = f.read()

signing = (
    "\n    signingConfigs {\n"
    "        release {\n"
    "            storeFile file(\"keystore.jks\")\n"
    f"            storePassword \"{pw}\"\n"
    f"            keyAlias \"{alias}\"\n"
    f"            keyPassword \"{pw}\"\n"
    "        }\n"
    "    }\n"
)

txt = re.sub(r"(android\s*\{)", r"\1" + signing, txt, count=1)
txt = re.sub(
    r"(buildTypes\s*\{[^\}]*release\s*\{)",
    r"\1\n            signingConfig signingConfigs.release",
    txt, count=1, flags=re.DOTALL,
)

with open(path, "w") as f:
    f.write(txt)

print("Signing config injected OK")
