#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner target
runner_target = project.targets.find { |target| target.name == 'Runner' }

if runner_target
  puts "Found Runner target"
  
  # Get all build phases
  build_phases = runner_target.build_phases
  
  # Find the problematic phases
  embed_extensions_phase = build_phases.find { |phase| 
    phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && 
    phase.dst_subfolder_spec == '13' # PlugIns folder
  }
  
  thin_binary_phase = build_phases.find { |phase| 
    phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && 
    phase.name == 'Thin Binary'
  }
  
  pods_resources_phase = build_phases.find { |phase| 
    phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && 
    phase.name == '[CP] Copy Pods Resources'
  }
  
  pods_frameworks_phase = build_phases.find { |phase| 
    phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && 
    phase.name == '[CP] Embed Pods Frameworks'
  }
  
  if embed_extensions_phase && thin_binary_phase
    puts "Reordering build phases to fix cycle..."
    
    # Remove the embed extensions phase
    runner_target.build_phases.delete(embed_extensions_phase)
    
    # Find the index of the Thin Binary phase
    thin_binary_index = runner_target.build_phases.index(thin_binary_phase)
    
    if thin_binary_index
      # Insert the embed extensions phase BEFORE the Thin Binary phase
      runner_target.build_phases.insert(thin_binary_index, embed_extensions_phase)
      puts "Moved Embed App Extensions phase before Thin Binary phase"
    end
  end
  
  # Save the project
  project.save
  puts "Project saved successfully"
else
  puts "Runner target not found"
end
