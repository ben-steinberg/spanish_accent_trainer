import os
import subprocess
import uuid



def to_textgrid(directory, language, output_directory):

    os.makedirs(os.path.abspath(directory), exist_ok=True)
        
    abs_input  = os.path.abspath(directory)
    abs_output = os.path.abspath(output_directory)
    os.makedirs(abs_output, exist_ok=True)
    
    print("abs_input:", abs_input)
    print("exists:", os.path.exists(abs_input))
    
    unique_temp = os.path.join("/tmp", f"mfa_{uuid.uuid4()}")
    os.makedirs(unique_temp, exist_ok=True)

    mfa_command = [
        '/opt/miniconda3/bin/mfa', 'align',
        abs_input, 'spanish_mfa', 'spanish_mfa', abs_output,
        '--clean',
        '--num_jobs', '4',
        '--no_debug',
        '--temp_directory', unique_temp
    ]

    env = os.environ.copy()
    env['PATH'] = '/opt/miniconda3/bin:' + env.get('PATH', '')
    env['CONDA_PREFIX'] = '/opt/miniconda3'

    print("running mfa")
    result = subprocess.run(mfa_command, capture_output=True, text=True,
                            check=False, env=env)
    print("STDOUT:", result.stdout[:3000])
    print("STDERR:", result.stderr[:3000])

    if result.returncode != 0:
        print(f"friggin failed for 1+ files: {result.returncode}")
        print("error output")
        print(result.stderr)
        print(result.stdout)
    else:
        print("done")

if __name__ == "__main__":
    to_textgrid("files_for_alignment", "spanish_mfa", "aligned_text_grids")
