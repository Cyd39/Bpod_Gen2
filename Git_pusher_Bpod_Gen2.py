import subprocess
import os
import tkinter as tk
from tkinter import messagebox, simpledialog
import datetime

def get_commit_message():
    """获取用户输入的commit message"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    
    # 设置默认message
    default_message = f"Update {datetime.datetime.now().strftime('%Y-%m-%d %H-%M-%S')}"
    
    # 弹出输入对话框
    commit_message = simpledialog.askstring("输入Commit Message", 
                                          "请输入commit message:", 
                                          initialvalue=default_message)
    
    root.destroy()
    return commit_message

def git_push(repo_path):
    """将代码推送到远程仓库"""
    try:
        # 切换到目标仓库目录
        os.chdir(repo_path)
        print(f"已切换到仓库目录：{os.getcwd()}")

        # 获取commit message
        commit_message = get_commit_message()
        if commit_message is None or commit_message.strip() == "":
            print("用户取消了操作或输入为空")
            return

        # 添加所有更改
        print("正在执行：git add .")
        subprocess.run(["git", "add", "."], check=True)

        # 提交更改
        print(f"正在执行：git commit -m \"{commit_message}\"")
        subprocess.run(["git", "commit", "-m", commit_message], check=True)

        # 推送更改到远程仓库
        print("正在执行：git push origin main")
        subprocess.run(["git", "push", "origin", "main"], check=True)

        # 弹出成功对话框
        show_success_message()

    except subprocess.CalledProcessError as e:
        print(f"命令执行失败：{e}")
        show_error_message(f"操作失败：{e.stderr}")

def show_success_message():
    """显示成功对话框"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    messagebox.showinfo("操作成功", "代码已成功推送到远程仓库！")
    root.destroy()

def show_error_message(message):
    """显示错误对话框"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    messagebox.showerror("操作失败", message)
    root.destroy()

if __name__ == "__main__":
    repo_path = r"Y:\Code\Bpod_Gen2"

    # 调用函数
    git_push(repo_path)