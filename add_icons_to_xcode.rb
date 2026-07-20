require 'xcodeproj'
require 'fileutils'

project_path = 'ios/Runner.xcodeproj'
unless File.exist?(project_path)
  puts "[add_icons_to_xcode] ERROR: #{project_path} not found."
  exit 1
end

project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# The group where files are normally added is the 'Runner' group
group = project.main_group.find_subpath('Runner', true)
resources_phase = target.resources_build_phase

added_count = 0

# Find all alternate icons copied to ios/Runner/ by patch_ios_plist.py
Dir.glob("ios/Runner/GP*.png").each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if reference already exists in the group to avoid duplicates
  existing_ref = group.files.find { |f| f.path == file_name }
  
  unless existing_ref
    # Create a new file reference relative to the group's directory (ios/Runner)
    file_ref = group.new_reference(file_name)
    # Add to the "Copy Bundle Resources" build phase
    resources_phase.add_file_reference(file_ref)
    puts "[add_icons_to_xcode] Added #{file_name} to Xcode project"
    added_count += 1
  else
    puts "[add_icons_to_xcode] #{file_name} is already in the Xcode project"
  end
end

if added_count > 0
  project.save
  puts "[add_icons_to_xcode] Xcode project saved successfully with #{added_count} new bundled icons."
else
  puts "[add_icons_to_xcode] No new icons needed to be added."
end
