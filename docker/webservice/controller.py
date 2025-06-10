# from flask import Flask, request, render_template
# import paramiko
# import os

# app = Flask(__name__)

# # Hàm thực hiện SSH tới runner
# def execute_on_runner(host, command):
#     try:
#         ssh = paramiko.SSHClient()
#         ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#         ssh.connect(host, username='runner', key_filename='/root/.ssh/id_rsa')
        
#         stdin, stdout, stderr = ssh.exec_command(command)
#         output = stdout.read().decode()
#         error = stderr.read().decode()
        
#         ssh.close()
#         return {"success": True, "output": output, "error": error}
#     except Exception as e:
#         return {"success": False, "error": str(e)}

# # Giao diện web
# @app.route('/')
# def index():
#     return render_template('index.html')

# # Endpoint nhận lệnh và gọi runner
# @app.route('/run-job', methods=['POST'])
# def run_job():
#     runner_ip = request.form.get('runner_ip')
#     command = request.form.get('command')
    
#     result = execute_on_runner(runner_ip, command)
    
#     if result['success']:
#         execute_on_runner(runner_ip, f"curl -i -X POST http://172.18.0.4:5000/receive-log -d 'log_data=Task completed'")
#         return f"Command executed successfully:<br><pre>{result['output']}</pre>"
#     else:
#         execute_on_runner(runner_ip, f"curl -i -X POST http://172.18.0.4:5000/receive-log -d 'log_data=Task failed'")
#         return f"Failed to execute command:<br><pre>{result['error']}</pre>", 500

# # @app.route('/receive-log', methods=['POST'])
# # def receive_log():
# #     runner_ip = request.remote_addr
# #     log_data = request.form.get('log_data')
# #     with open(f'logs/{runner_ip}.log', 'a') as log_file:
# #         log_file.write(log_data + '\n')
# #     return "Log received", 200


# @app.route('/receive-log', methods=['POST'])
# def receive_log():
#     runner_ip = request.remote_addr
#     log_data = request.form.get('log_data')
    
#     # Tạo thư mục nếu chưa tồn tại
#     os.makedirs('logs', exist_ok=True)
    
#     # Ghi log
#     with open(f'logs/{runner_ip}.log', 'a') as log_file:
#         log_file.write(log_data + '\n')
    
#     return "Log received", 200


# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=5000)




# from flask import Flask, request, render_template, jsonify, redirect, url_for
# import paramiko
# import os

# app = Flask(__name__)

# # Danh sách runner (có thể thay thế bằng database)
# runners = []

# # Hàm thực hiện SSH tới runner
# def execute_on_runner(host, command):
#     try:
#         ssh = paramiko.SSHClient()
#         ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#         ssh.connect(host, username='runner', key_filename='/root/.ssh/id_rsa')

#         stdin, stdout, stderr = ssh.exec_command(command)
#         output = stdout.read().decode()
#         error = stderr.read().decode()

#         ssh.close()
#         return {"success": True, "output": output, "error": error}
#     except Exception as e:
#         return {"success": False, "error": str(e)}

# # Trang chủ hiển thị danh sách runner
# @app.route('/')
# def index():
#     return render_template('index.html', runners=runners)

# # Thêm runner
# @app.route('/add-runner', methods=['POST'])
# def add_runner():
#     ip = request.form.get('runner_ip')
#     if ip and ip not in runners:
#         runners.append(ip)
#     return redirect(url_for('index'))

# # Xóa runner
# @app.route('/remove-runner', methods=['POST'])
# def remove_runner():
#     ip = request.form.get('runner_ip')
#     if ip in runners:
#         runners.remove(ip)
#     return redirect(url_for('index'))

# # Kiểm tra trạng thái runner
# @app.route('/check-status', methods=['POST'])
# def check_status():
#     ip = request.form.get('runner_ip')
#     if ip in runners:
#         result = execute_on_runner(ip, "echo 'Checking status'")
#         return jsonify({"runner_ip": ip, "status": result['success'], "message": result['error'] if not result['success'] else "Online"})
#     return jsonify({"runner_ip": ip, "status": False, "message": "Runner not found"})

# # Gửi lệnh và nhận kết quả
# @app.route('/run-job', methods=['POST'])
# def run_job():
#     runner_ip = request.form.get('runner_ip')
#     command = request.form.get('command')

#     result = execute_on_runner(runner_ip, command)
#     if result['success']:
#         return f"Command executed successfully:<br><pre>{result['output']}</pre>"
#     else:
#         return f"Failed to execute command:<br><pre>{result['error']}</pre>", 500

# # Nhận log từ runner
# @app.route('/receive-log', methods=['POST'])
# def receive_log():
#     runner_ip = request.remote_addr
#     log_data = request.form.get('log_data')

#     os.makedirs('logs', exist_ok=True)
#     with open(f'logs/{runner_ip}.log', 'a') as log_file:
#         log_file.write(log_data + '\n')

#     return "Log received", 200

# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=5000)





from flask import Flask, request, render_template, jsonify, redirect, url_for
import paramiko
import os

app = Flask(__name__)

# Danh sách runner (có thể thay thế bằng database)
runners = []

# Hàm thực hiện SSH tới runner
def execute_on_runner(host, command):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, username='runner', key_filename='/root/.ssh/id_rsa')

        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode()
        error = stderr.read().decode()

        ssh.close()
        return {"success": True, "output": output, "error": error}
    except Exception as e:
        return {"success": False, "error": str(e)}

# Trang chủ hiển thị danh sách runner
@app.route('/')
def index():
    logs = {}
    for runner in runners:
        log_file_path = f'logs/{runner}.log'
        if os.path.exists(log_file_path):
            with open(log_file_path, 'r') as file:
                logs[runner] = file.read()
        else:
            logs[runner] = "No logs available"
    return render_template('index.html', runners=runners, logs=logs)

# Thêm runner
@app.route('/add-runner', methods=['POST'])
def add_runner():
    ip = request.form.get('runner_ip')
    if ip and ip not in runners:
        runners.append(ip)
    # Không thực hiện bất kỳ lệnh SSH nào tại đây.
    return redirect(url_for('index'))

# Xóa runner
@app.route('/remove-runner', methods=['POST'])
def remove_runner():
    ip = request.form.get('runner_ip')
    if ip in runners:
        runners.remove(ip)
    return redirect(url_for('index'))

# Kiểm tra trạng thái runner
@app.route('/check-status', methods=['POST'])
def check_status():
    ip = request.form.get('runner_ip')
    if ip in runners:
        result = execute_on_runner(ip, "echo 'Checking status'")
        if result['success']:
            message = "Runner is Online"
        else:
            message = f"Runner is Offline: {result['error']}"
        return jsonify({"runner_ip": ip, "status": result['success'], "message": message})
    return jsonify({"runner_ip": ip, "status": False, "message": "Runner not found"})

# Gửi lệnh tới nhiều runner
# @app.route('/run-job', methods=['POST'])
# def run_job():
#     print(request.form)  # In toàn bộ dữ liệu form
#     selected_runners = request.form.getlist('runner_ips')
#     command = request.form.get('command')
#     print(f"Selected runners: {selected_runners}")
#     return jsonify({"command": command, "selected_runners": selected_runners})


@app.route('/run-job', methods=['POST'])
def run_job():
    selected_runners = request.form.getlist('runner_ips')
    command = request.form.get('command')
    results = {}
    # return jsonify(selected_runners=selected_runners, command=command)

    for runner_ip in selected_runners:
        result = execute_on_runner(runner_ip, command)
        results[runner_ip] = result
    response = {"success": {}, "failed": {}}
    for runner_ip, result in results.items():
        if result['success']:
            execute_on_runner(runner_ip, f"curl -i -X POST http://172.18.0.4:5000/receive-log -d 'log_data=Task completed {command}'")
            response["success"][runner_ip] = result['output']
        else:
            execute_on_runner(runner_ip, f"curl -i -X POST http://172.18.0.4:5000/receive-log -d 'log_data=Task completed {command}'")
            response["failed"][runner_ip] = result['error']

    return jsonify(response)

# Nhận log từ runner
@app.route('/receive-log', methods=['POST'])
def receive_log():
    runner_ip = request.remote_addr
    log_data = request.form.get('log_data')

    os.makedirs('logs', exist_ok=True)
    with open(f'logs/{runner_ip}.log', 'a') as log_file:
        log_file.write(log_data + '\n')

    return "Log received", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)