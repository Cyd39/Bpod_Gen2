import subprocess
import os
import tkinter as tk
from tkinter import messagebox, simpledialog, filedialog, ttk
import datetime

class GitPusherGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Git Pusher")
        self.root.geometry("600x400")
        self.root.resizable(True, True)
        
        # 居中显示窗口
        self.root.eval('tk::PlaceWindow . center')
        
        self.setup_ui()
        
    def setup_ui(self):
        """设置用户界面"""
        # 主框架
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill='both', expand=True)
        
        # 仓库路径选择
        path_frame = ttk.LabelFrame(main_frame, text="仓库设置", padding="10")
        path_frame.pack(fill='x', pady=(0, 10))
        
        ttk.Label(path_frame, text="仓库路径:").pack(anchor='w')
        
        self.path_var = tk.StringVar(value=r"Y:\Code\Bpod_Gen2")
        path_entry = ttk.Entry(path_frame, textvariable=self.path_var, width=50)
        path_entry.pack(side='left', fill='x', expand=True, pady=(5, 0))
        
        ttk.Button(path_frame, text="浏览", command=self.browse_folder).pack(side='right', padx=(5, 0), pady=(5, 0))
        
        # Git信息显示
        info_frame = ttk.LabelFrame(main_frame, text="Git信息", padding="10")
        info_frame.pack(fill='x', pady=(0, 10))
        
        self.info_text = tk.Text(info_frame, height=8, width=70)
        info_scroll = ttk.Scrollbar(info_frame, orient='vertical', command=self.info_text.yview)
        self.info_text.configure(yscrollcommand=info_scroll.set)
        
        self.info_text.pack(side='left', fill='both', expand=True)
        info_scroll.pack(side='right', fill='y')
        
        # 按钮框架
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill='x', pady=(10, 0))
        
        ttk.Button(button_frame, text="检查Git状态", command=self.check_git_status).pack(side='left', padx=(0, 5))
        ttk.Button(button_frame, text="提交并推送", command=self.commit_and_push).pack(side='left', padx=(0, 5))
        ttk.Button(button_frame, text="退出", command=self.root.destroy).pack(side='right')
        
        # 初始检查
        self.check_git_status()
        
    def browse_folder(self):
        """浏览文件夹"""
        folder = filedialog.askdirectory(initialdir=self.path_var.get())
        if folder:
            self.path_var.set(folder)
            self.check_git_status()
    
    def check_git_status(self):
        """检查Git状态"""
        self.info_text.delete('1.0', tk.END)
        repo_path = self.path_var.get()
        
        if not os.path.exists(repo_path):
            self.info_text.insert('1.0', f"错误：路径不存在\n{repo_path}")
            return
        
        if not os.path.exists(os.path.join(repo_path, ".git")):
            self.info_text.insert('1.0', f"错误：指定路径不是Git仓库\n{repo_path}")
            return
        
        try:
            os.chdir(repo_path)
            
            # 获取当前分支
            branch_result = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True)
            if branch_result.returncode == 0:
                current_branch = branch_result.stdout.strip()
                self.info_text.insert('1.0', f"当前分支：{current_branch}\n\n")
            else:
                self.info_text.insert('1.0', "无法获取当前分支\n\n")
            
            # 获取Git状态
            status_result = subprocess.run(["git", "status"], capture_output=True, text=True)
            if status_result.returncode == 0:
                self.info_text.insert(tk.END, "Git状态：\n")
                self.info_text.insert(tk.END, status_result.stdout)
            else:
                self.info_text.insert(tk.END, f"获取Git状态失败：{status_result.stderr}")
            
            # 获取最近的提交
            log_result = subprocess.run(["git", "log", "--oneline", "-3"], capture_output=True, text=True)
            if log_result.returncode == 0 and log_result.stdout:
                self.info_text.insert(tk.END, "\n\n最近的提交：\n")
                self.info_text.insert(tk.END, log_result.stdout)
                
        except Exception as e:
            self.info_text.insert('1.0', f"检查Git状态失败：{e}")
    
    def get_commit_message(self):
        """获取用户输入的commit message"""
        # 设置默认message
        default_message = f"Update {datetime.datetime.now().strftime('%Y-%m-%d %H-%M-%S')}"
        
        # 弹出输入对话框
        commit_message = simpledialog.askstring("输入Commit Message", 
                                              "请输入commit message:", 
                                              initialvalue=default_message,
                                              parent=self.root)
        return commit_message
    
    def commit_and_push(self):
        """提交并推送代码"""
        repo_path = self.path_var.get()
        
        if not os.path.exists(repo_path):
            messagebox.showerror("错误", f"路径不存在：{repo_path}", parent=self.root)
            return
        
        if not os.path.exists(os.path.join(repo_path, ".git")):
            messagebox.showerror("错误", f"指定路径不是Git仓库：{repo_path}", parent=self.root)
            return
        
        try:
            os.chdir(repo_path)
            
            # 检查是否有更改
            status_result = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
            if not status_result.stdout.strip():
                messagebox.showinfo("提示", "没有需要提交的更改！", parent=self.root)
                return
            
            # 获取commit message
            commit_message = self.get_commit_message()
            if commit_message is None or commit_message.strip() == "":
                print("用户取消了操作或输入为空")
                return
            
            # 获取当前分支
            branch_result = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, check=True)
            current_branch = branch_result.stdout.strip()
            
            # 添加所有更改
            print("正在执行：git add .")
            subprocess.run(["git", "add", "."], check=True)
            
            # 提交更改
            print(f"正在执行：git commit -m \"{commit_message}\"")
            subprocess.run(["git", "commit", "-m", commit_message], check=True)
            
            # 推送更改到远程仓库
            print(f"正在执行：git push origin {current_branch}")
            subprocess.run(["git", "push", "origin", current_branch], check=True)
            
            # 弹出成功对话框
            messagebox.showinfo("成功", "代码已成功推送到远程仓库！", parent=self.root)
            
            # 更新状态显示
            self.check_git_status()
            
        except subprocess.CalledProcessError as e:
            error_msg = f"Git操作失败：\n命令：{e.cmd}\n返回码：{e.returncode}\n错误信息：{e.stderr if e.stderr else '无详细信息'}"
            messagebox.showerror("错误", error_msg, parent=self.root)
        except Exception as e:
            messagebox.showerror("错误", f"发生错误：{str(e)}", parent=self.root)
    
    def run(self):
        """运行GUI"""
        self.root.mainloop()

def main():
    """主函数"""
    app = GitPusherGUI()
    app.run()

if __name__ == "__main__":
    main()