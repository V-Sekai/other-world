environment_variables: [{
	name:  "GODOT_STATUS"
	value: "model_explorer-4.3"
}]
group:          "gamma"
label_template: "model_explorer-4.3.${godot-groups-editor_pipeline_dependency}.${COUNT}"
materials: [{
	branch:      "main"
	destination: "g"
	name:        "project_git_sandbox"
	type:        "git"
	url:         "https://github.com/V-Sekai/TOOL_model_explorer.git"
}, {
	ignore_for_scheduling: false
	name:                  "godot-groups-editor_pipeline_dependency"
	pipeline:              "godot-groups"
	stage:                 "templateZipStage"
	type:                  "dependency"
}]
name: "town-courier-export"
stages: [{
	clean_workspace: true
	fetch_materials: true
	jobs: [{
		artifacts: [{
			destination: ""
			source:      "export_windows"
			type:        "build"
		}]
		name: "windows_job"
		resources: ["linux", "mingw5"]
		tasks: [{
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "defaultJob"
			pipeline:         "godot-groups"
			source:           "godot.templates.tpz"
			stage:            "templateZipStage"
			type:             "fetch"
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "linux_job"
			pipeline:         "godot-groups"
			source:           "godot.linuxbsd.editor.double.x86_64.llvm"
			stage:            "defaultStage"
			type:             "fetch"
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "linux_job"
			pipeline:         "godot-groups"
			source:           "godot.linuxbsd.editor.double.x86_64.llvm"
			stage:            "defaultStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "rm -rf templates && unzip \"godot.templates.tpz\" && export VERSION=\"`cat templates/version.txt`\" && export TEMPLATEDIR=\".local/share/godot/export_templates/$VERSION/\" && export HOME=\"`pwd`\" && export BASEDIR=\"`pwd`\" && rm -rf \"$TEMPLATEDIR\" && mkdir -p \"$TEMPLATEDIR\" && cd \"$TEMPLATEDIR\" && mv \"$BASEDIR\"/templates/* ."]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "(echo \"## AUTOGENERATED BY BUILD\"; echo \"\"; echo \"const BUILD_LABEL = \\\"$GO_PIPELINE_LABEL\\\"\"; echo \"const BUILD_DATE_STR = \\\"$(date --utc --iso=seconds)\\\"\"; echo \"const BUILD_UNIX_TIME = $(date +%s)\" ) > addons/vsk_version/build_constants.gd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: "g"
		}, {
			arguments: ["-c", "rm -rf export_windows"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mkdir export_windows"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "chmod +x godot.linuxbsd.editor.double.x86_64.llvm"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "ls templates"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "unzip godot.templates.tpz"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "cp templates/windows_release_x86_64.exe export_windows/v_sekai_windows.exe"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "../godot.linuxbsd.editor.double.x86_64.llvm --headless --xr-mode off --export-pack \"Windows\" `pwd`/../export_windows/v_sekai_windows.exe.pck"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: "g"
		}, {
			arguments: ["-c", "ls export_windows"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}]
	}, {
		artifacts: [{
			destination: ""
			source:      "export_linuxbsd"
			type:        "build"
		}]
		name: "linux_job"
		resources: ["linux", "mingw5"]
		tasks: [{
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "defaultJob"
			pipeline:         "godot-groups"
			source:           "godot.templates.tpz"
			stage:            "templateZipStage"
			type:             "fetch"
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "linux_job"
			pipeline:         "godot-groups"
			source:           "godot.linuxbsd.editor.double.x86_64.llvm"
			stage:            "defaultStage"
			type:             "fetch"
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: true
			job:              "linux_job"
			pipeline:         "godot-groups"
			source:           "godot.linuxbsd.editor.double.x86_64.llvm"
			stage:            "defaultStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "rm -rf templates && unzip \"godot.templates.tpz\" && export VERSION=\"`cat templates/version.txt`\" && export TEMPLATEDIR=\".local/share/godot/export_templates/$VERSION/\" && export HOME=\"`pwd`\" && export BASEDIR=\"`pwd`\" && rm -rf \"$TEMPLATEDIR\" && mkdir -p \"$TEMPLATEDIR\" && cd \"$TEMPLATEDIR\" && mv \"$BASEDIR\"/templates/* ."]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "(echo \"## AUTOGENERATED BY BUILD\"; echo \"\"; echo \"const BUILD_LABEL = \\\"$GO_PIPELINE_LABEL\\\"\"; echo \"const BUILD_DATE_STR = \\\"$(date --utc --iso=seconds)\\\"\"; echo \"const BUILD_UNIX_TIME = $(date +%s)\" ) > addons/vsk_version/build_constants.gd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: "g"
		}, {
			arguments: ["-c", "rm -rf export_linuxbsd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mkdir export_linuxbsd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "chmod +x godot.linuxbsd.editor.double.x86_64.llvm"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "ls templates"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "unzip godot.templates.tpz"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "cp templates/linux_release.x86_64 export_linuxbsd/v_sekai_linuxbsd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "../godot.linuxbsd.editor.double.x86_64.llvm --headless --xr-mode off --export-pack \"Linux\" `pwd`/../export_linuxbsd/v_sekai_linuxbsd.pck"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: "g"
		}, {
			arguments: ["-c", "ls export_linuxbsd"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}]
	}]
	name: "exportStage"
}, {
	clean_workspace: false
	jobs: [{
		name: "windows_job"
		resources: ["linux", "mingw5"]
		tasks: [{
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: false
			job:              "windows_job"
			pipeline:         "town-courier-export"
			source:           "export_windows"
			stage:            "exportStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "mkdir -p export/game"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mkdir -p export/editor"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mv export_windows/* export/game"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: false
			job:              "windows_job"
			pipeline:         "town-courier-export"
			source:           "export_windows"
			stage:            "exportStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "mv export_windows/v_sekai_windows.exe export/editor/v_sekai_windows_editor.exe"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", """
				cat > export/.itch.toml <<EOF
				[[actions]]
				name = "play"
				path = "game/v_sekai_linuxbsd"
				platform = "linux"

				[[actions]]
				name = "editor"
				path = "editor/v_sekai_linuxbsd_editor"
				platform = "linux"

				[[actions]]
				name = "play"
				path = "game/v_sekai_windows.exe"
				platform = "windows"

				[[actions]]
				name = "editor"
				path = "editor/v_sekai_windows_editor.exe"
				platform = "windows"

				[[actions]]
				name = "forums"
				path = "https://discord.gg/7BQDHesck8"

				[[actions]]
				name = "Manuals"
				path = "https://v-sekai.github.io/manuals/"
				EOF
				"""]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "butler push export ifiregames/town-courier:windows-master --userversion $GO_PIPELINE_LABEL-`date --iso=seconds --utc`"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}]
	}, {
		name: "linux_job"
		resources: ["linux", "mingw5"]
		tasks: [{
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: false
			job:              "linux_job"
			pipeline:         "town-courier-export"
			source:           "export_linuxbsd"
			stage:            "exportStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "mkdir -p export/game"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mkdir -p export/editor"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "mv export_linuxbsd/* export/game"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			artifact_origin:  "gocd"
			destination:      ""
			is_source_a_file: false
			job:              "linux_job"
			pipeline:         "town-courier-export"
			source:           "export_linuxbsd"
			stage:            "exportStage"
			type:             "fetch"
		}, {
			arguments: ["-c", "mv export_linuxbsd/v_sekai_linuxbsd export/editor/v_sekai_linuxbsd_editor"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", """
				cat > export/.itch.toml <<EOF
				[[actions]]
				name = "play"
				path = "game/v_sekai_linuxbsd"
				platform = "linux"

				[[actions]]
				name = "editor"
				path = "editor/v_sekai_linuxbsd_editor"
				platform = "linux"

				[[actions]]
				name = "play"
				path = "game/v_sekai_windows.exe"
				platform = "windows"

				[[actions]]
				name = "editor"
				path = "editor/v_sekai_windows_editor.exe"
				platform = "windows"

				[[actions]]
				name = "forums"
				path = "https://discord.gg/7BQDHesck8"

				[[actions]]
				name = "Manuals"
				path = "https://v-sekai.github.io/manuals/"
				EOF
				"""]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}, {
			arguments: ["-c", "butler push export ifiregames/town-courier:linux-master --userversion $GO_PIPELINE_LABEL-`date --iso=seconds --utc`"]
			command:           "/bin/bash"
			type:              "exec"
			working_directory: ""
		}]
	}]
	name: "uploadStage"
}]
