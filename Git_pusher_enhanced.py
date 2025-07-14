import subprocess
import os
import tkinter as tk
from tkinter import messagebox, ttk, filedialog
import datetime
import json

class EnhancedGitPusher:
    def __init__(self):
        self.root = None
        self.config_file = "git_pusher_config.json"
        self.load_config()
        
    def load_config(self):
        """加载配置文件"""
        self.config = {
            "repo_path": r"Y:\Code\Bpod_Gen2",
            "default_branch": "main",
            "auto_push": True
        }
        
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    saved_config = json.load(f)
                    self.config.update(saved_config)
            except Exception as e:
                print(f"加载配置文件失败：{e}")
    
    def save_config(self):
        """保存配置文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"保存配置文件失败：{e}")
    
    def show_main_window(self):
        """显示主窗口"""
        self.root = tk.Tk()
        self.root.title("Git Pusher")
        self.root.geometry("500x600")
        self.root.resizable(True, True)
        
        # 居中显示窗口
        self.root.eval('tk::PlaceWindow . center')
        
        # 创建主框架
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill='both', expand=True)
        
        # 仓库路径选择
        path_frame = ttk.LabelFrame(main_frame, text="仓库设置", padding="10")
        path_frame.pack(fill='x', pady=(0, 10))
        
        ttk.Label(path_frame, text="仓库路径:").pack(anchor='w')
        
        path_var = tk.StringVar(value=self.config["repo_path"])
        path_entry = ttk.Entry(path_frame, textvariable=path_var, width=50)
        path_entry.pack(side='left', fill='x', expand=True, pady=(5, 0))
        
        def browse_path():
            path = filedialog.askdirectory(initialdir=self.config["repo_path"])
            if path:
                path_var.set(path)
                self.config["repo_path"] = path
        
        ttk.Button(path_frame, text="浏览", command=browse_path).pack(side='right', padx=(5, 0), pady=(5, 0))
        
        # 分支设置
        branch_frame = ttk.Frame(path_frame)
        branch_frame.pack(fill='x', pady=(10, 0))
        
        ttk.Label(branch_frame, text="分支:").pack(side='left')
        branch_var = tk.StringVar(value=self.config["default_branch"])
        branch_entry = ttk.Entry(branch_frame, textvariable=branch_var, width=20)
        branch_entry.pack(side='left', padx=(5, 0))
        
        # 选项设置
        options_frame = ttk.LabelFrame(main_frame, text="选项", padding="10")
        options_frame.pack(fill='x', pady=(0, 10))
        
        auto_push_var = tk.BooleanVar(value=self.config["auto_push"])
        ttk.Checkbutton(options_frame, text="自动推送", variable=auto_push_var).pack(anchor='w')
        
        # Git状态显示
        status_frame = ttk.LabelFrame(main_frame, text="Git状态", padding="10")
        status_frame.pack(fill='both', expand=True, pady=(0, 10))
        
        self.status_text = tk.Text(status_frame, height=10, width=70)
        status_text_scroll = ttk.Scrollbar(status_frame, orient='vertical', command=self.status_text.yview)
        self.status_text.configure(yscrollcommand=status_text_scroll.set)
        
        self.status_text.pack(side='left', fill='both', expand=True)
        status_text_scroll.pack(side='right', fill='y')
        
        # 按钮框架
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill='x', pady=(10, 0))
        
        ttk.Button(button_frame, text="检查状态", command=lambda: self.check_status(path_var.get())).pack(side='left', padx=(0, 5))
        ttk.Button(button_frame, text="提交并推送", command=lambda: self.commit_and_push(
            path_var.get(), branch_var.get(), auto_push_var.get()
        )).pack(side='left', padx=(0, 5))
        ttk.Button(button_frame, text="保存设置", command=lambda: self.save_settings(
            path_var.get(), branch_var.get(), auto_push_var.get()
        )).pack(side='left', padx=(0, 5))
        ttk.Button(button_frame, text="退出", command=self.root.destroy).pack(side='right')
        
        # 初始检查状态
        self.check_status(path_var.get())
        
        # 运行主循环
        self.root.mainloop()
    
    def check_status(self, repo_path):
        """检查Git状态"""
        self.status_text.delete('1.0', tk.END)
        
        if not os.path.exists(repo_path):
            self.status_text.insert('1.0', f"错误：仓库路径不存在\n{repo_path}")
            return
        
        if not os.path.exists(os.path.join(repo_path, ".git")):
            self.status_text.insert('1.0', f"错误：指定路径不是Git仓库\n{repo_path}")
            return
        
        try:
            os.chdir(repo_path)
            
            # 获取Git状态
            result = subprocess.run(["git", "status"], capture_output=True, text=True)
            if result.returncode != 0:
                self.status_text.insert('1.0', f"Git状态检查失败：\n{result.stderr}")
                return
                
            self.status_text.insert('1.0', f"仓库路径：{repo_path}\n\n")
            self.status_text.insert(tk.END, result.stdout)
            
            # 获取最近的提交
            commit_result = subprocess.run(["git", "log", "--oneline", "-5"], capture_output=True, text=True)
            if commit_result.returncode == 0 and commit_result.stdout:
                self.status_text.insert(tk.END, "\n\n最近的提交：\n")
                self.status_text.insert(tk.END, commit_result.stdout)
            elif commit_result.returncode != 0:
                self.status_text.insert(tk.END, f"\n\n获取提交历史失败：{commit_result.stderr}")
                
        except Exception as e:
            self.status_text.insert('1.0', f"检查状态失败：{e}")
    
    def get_commit_message(self):
        """获取commit message"""
        dialog = tk.Toplevel(self.root)
        dialog.title("输入Commit Message")
        dialog.geometry("500x300")
        dialog.transient(self.root)
        dialog.grab_set()
        
        # 居中显示对话框
        dialog.update_idletasks()  # 更新窗口信息
        
        ttk.Label(dialog, text="请输入commit message:", font=("Arial", 12)).pack(pady=10)
        
        text_widget = tk.Text(dialog, height=8, width=50, font=("Arial", 10))
        text_widget.pack(pady=10, padx=20, fill='both', expand=True)
        
        # 设置默认message
        default_message = f"Update {datetime.datetime.now().strftime('%Y-%m-%d %H-%M-%S')}"
        text_widget.insert('1.0', default_message)
        
        commit_message = [None]
        
        def on_ok():
            commit_message[0] = text_widget.get('1.0', 'end-1c').strip()
            if not commit_message[0]:
                messagebox.showwarning("警告", "Commit message不能为空！", parent=dialog)
                return
            dialog.destroy()
        
        def on_cancel():
            commit_message[0] = None
            dialog.destroy()
        
        button_frame = ttk.Frame(dialog)
        button_frame.pack(pady=10)
        
        ttk.Button(button_frame, text="确定", command=on_ok).pack(side='left', padx=5)
        ttk.Button(button_frame, text="取消", command=on_cancel).pack(side='left', padx=5)
        
        text_widget.bind('<Return>', lambda e: on_ok())
        text_widget.bind('<Escape>', lambda e: on_cancel())
        text_widget.focus_set()
        
        dialog.wait_window()
        return commit_message[0]
    
    def commit_and_push(self, repo_path, branch, auto_push):
        """提交并推送代码"""
        try:
            if not os.path.exists(repo_path):
                messagebox.showerror("错误", f"仓库路径不存在：{repo_path}", parent=self.root)
                return
            
            if not os.path.exists(os.path.join(repo_path, ".git")):
                messagebox.showerror("错误", f"指定路径不是Git仓库：{repo_path}", parent=self.root)
                return
            
            os.chdir(repo_path)
            
            # 检查是否有更改
            status_result = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
            if not status_result.stdout.strip():
                messagebox.showinfo("提示", "没有需要提交的更改！", parent=self.root)
                return
            
            # 获取commit message
            commit_msg = self.get_commit_message()
            if commit_msg is None:
                return
            
            # 添加所有更改
            add_result = subprocess.run(["git", "add", "."], capture_output=True, text=True, check=True)
            
            # 提交
            commit_result = subprocess.run(["git", "commit", "-m", commit_msg], capture_output=True, text=True, check=True)
            
            # 推送
            if auto_push:
                push_result = subprocess.run(["git", "push", "origin", branch], capture_output=True, text=True, check=True)
                messagebox.showinfo("成功", f"代码已成功推送到 {branch} 分支！", parent=self.root)
            else:
                messagebox.showinfo("成功", "代码已提交，请手动推送！", parent=self.root)
            
            # 更新状态显示
            self.check_status(repo_path)
            
        except subprocess.CalledProcessError as e:
            error_msg = f"Git操作失败：\n命令：{e.cmd}\n返回码：{e.returncode}\n错误信息：{e.stderr if e.stderr else '无详细信息'}"
            messagebox.showerror("错误", error_msg, parent=self.root)
        except Exception as e:
            messagebox.showerror("错误", f"发生错误：{str(e)}", parent=self.root)
    
    def save_settings(self, repo_path, branch, auto_push):
        """保存设置"""
        self.config.update({
            "repo_path": repo_path,
            "default_branch": branch,
            "auto_push": auto_push
        })
        self.save_config()
        messagebox.showinfo("成功", "设置已保存！", parent=self.root)

def main():
    """主函数"""
    pusher = EnhancedGitPusher()
    pusher.show_main_window()

if __name__ == "__main__":
    main() 