import os

# 1. Modify project.pbxproj
pbxproj_path = "ios/Runner.xcodeproj/project.pbxproj"
if os.path.exists(pbxproj_path):
    print("Modifying project.pbxproj...")
    with open(pbxproj_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Disable code signing in Runner project settings
    content = content.replace(
        "buildSettings = {",
        'buildSettings = {\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;\n\t\t\t\tCODE_SIGN_IDENTITY = "";\n\t\t\t\tDEVELOPMENT_TEAM = "";'
    )
    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(content)
else:
    print("project.pbxproj not found!")

# 2. Modify Podfile
podfile_path = "ios/Podfile"
if os.path.exists(podfile_path):
    print("Modifying Podfile...")
    with open(podfile_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    target_str = "flutter_additional_ios_build_settings(target)"
    replacement_str = (
        "flutter_additional_ios_build_settings(target)\n"
        "    target.build_configurations.each do |config|\n"
        "      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'\n"
        "      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'\n"
        "      config.build_settings['DEVELOPMENT_TEAM'] = ''\n"
        "    end"
    )
    if target_str in content:
        content = content.replace(target_str, replacement_str)
    else:
        # Fallback if the structure is different
        content += "\n\npost_install do |installer|\n  installer.pods_project.targets.each do |target|\n    target.build_configurations.each do |config|\n      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'\n      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'\n      config.build_settings['DEVELOPMENT_TEAM'] = ''\n    end\n  end\nend\n"
        
    with open(podfile_path, "w", encoding="utf-8") as f:
        f.write(content)
else:
    print("Podfile not found!")
