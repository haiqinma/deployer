#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import glob
import shutil
import logging
import importlib.util
import select
from pathlib import Path

# ================= 依赖检查区 =================
def check_dependencies():
    """
    检查运行环境是否安装了必要的第三方库。
    如果缺失，打印提示并退出脚本。
    """
    required_libs = {
        "yaml": "PyYAML"
    }
    
    missing_libs = []
    for module_name, package_name in required_libs.items():
        if importlib.util.find_spec(module_name) is None:
            missing_libs.append(package_name)
            
    if missing_libs:
        print(f"[错误] 缺少必要的依赖库: {', '.join(missing_libs)}")
        print(f"[提示] 请运行以下命令进行安装:")
        print(f"       pip3 install {' '.join(missing_libs)}")
        sys.exit(1)

# 在导入 yaml 之前执行依赖检查
check_dependencies()

import yaml
# =============================================

# ================= 配置区 =================
SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = SCRIPT_DIR / "cleanup_rules.yaml"
LOG_FILE = "/opt/logs/cleanup-item.log"
MAX_LOG_BYTES = 1 * 1024 * 1024  # 1MB
# =========================================

def setup_logger():
    """
    配置日志记录器。
    如果日志文件大于1MB，则清空日志文件。
    """
    log_dir = os.path.dirname(LOG_FILE)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    # 检查日志文件大小，超过1MB则清空
    if os.path.exists(LOG_FILE):
        if os.path.getsize(LOG_FILE) > MAX_LOG_BYTES:
            with open(LOG_FILE, 'w', encoding='utf-8') as f:
                f.truncate(0)  # 清空文件内容

    logger = logging.getLogger("CleanupLogger")
    logger.setLevel(logging.INFO)

    # 避免重复添加 handler
    if not logger.handlers:
        file_handler = logging.FileHandler(LOG_FILE, encoding='utf-8')
        console_handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger

def validate_rule(rule, logger):
    """校验规则合法性：前缀和后缀不能同时为空"""
    prefix = rule.get('prefix', '')
    suffix = rule.get('suffix', '')
    if not prefix and not suffix:
        logger.error(f"[规则校验失败] 路径 {rule.get('path')} 的前缀和后缀不能同时为空！已跳过。")
        return False
    return True

def confirm_delete(item_type, target, timeout=5):
    """删除前确认：5 秒内输入 y/Y 才执行删除。"""
    sys.stdout.write(f"确认删除{item_type}: {target} ? 请输入 y/Y 确认（{timeout}秒内）：")
    sys.stdout.flush()

    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        sys.stdout.write("\n")
        sys.stdout.flush()
        return False

    answer = sys.stdin.readline().strip()
    return answer in ("y", "Y")

def process_file_rule(rule, dry_run, logger):
    """处理文件类型的清理规则"""
    path = rule['path']
    prefix = rule.get('prefix', '')
    suffix = rule.get('suffix', '')
    keep_count = rule.get('keep_count', 0)
    sort_by = rule.get('sort_by', 'mtime')

    # 构建通配符匹配模式
    pattern = os.path.join(path, f"{prefix}*{suffix}")
    files = [f for f in glob.glob(pattern) if os.path.isfile(f)]

    # 按时间排序 (降序，最新的在前面)
    try:
        if sort_by == 'ctime':
            files.sort(key=lambda x: os.path.getctime(x), reverse=True)
        else:  # 默认 mtime
            files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    except Exception as e:
        logger.error(f"排序文件时出错: {e}")
        return

    # 核心逻辑：切片获取需要删除的文件
    files_to_delete = files[keep_count:]
    
    if not files_to_delete:
        logger.info(f"[跳过] {path} 下匹配文件数({len(files)}) <= 保留数({keep_count})，无需清理。")
        return

    logger.info(f"[执行] 在 {path} 下找到 {len(files)} 个文件，保留 {keep_count} 个，准备删除 {len(files_to_delete)} 个。")
    for f in files_to_delete:
        if dry_run:
            logger.info(f"[DRY RUN] 模拟删除文件: {f}")
        else:
            if not confirm_delete("文件", f):
                logger.info(f"[跳过] 未确认删除文件: {f}")
                continue
            try:
                os.remove(f)
                logger.info(f"[成功] 已删除文件: {f}")
            except Exception as e:
                logger.error(f"[失败] 删除文件失败 {f}: {e}")

def process_folder_rule(rule, dry_run, logger):
    """处理文件夹类型的清理规则"""
    path = rule['path']
    prefix = rule.get('prefix', '')
    suffix = rule.get('suffix', '')
    keep_count = rule.get('keep_count', 0)
    sort_by = rule.get('sort_by', 'mtime')

    pattern = os.path.join(path, f"{prefix}*{suffix}")
    folders = [f for f in glob.glob(pattern) if os.path.isdir(f)]

    if not folders:
        logger.info(f"[跳过] {path} 下未找到匹配的文件夹。")
        return

    try:
        if sort_by == 'ctime':
            folders.sort(key=lambda x: os.path.getctime(x), reverse=True)
        else:  # 默认 mtime
            folders.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    except Exception as e:
        logger.error(f"排序文件夹时出错: {e}")
        return

    folders_to_delete = folders[keep_count:]

    if not folders_to_delete:
        logger.info(f"[跳过] {path} 下匹配文件夹数({len(folders)}) <= 保留数({keep_count})，无需清理。")
        return

    logger.info(f"[执行] 在 {path} 下找到 {len(folders)} 个文件夹，保留 {keep_count} 个，准备删除 {len(folders_to_delete)} 个。")
    for folder in folders_to_delete:
        if dry_run:
            logger.info(f"[DRY RUN] 模拟删除文件夹: {folder}")
        else:
            if not confirm_delete("文件夹", folder):
                logger.info(f"[跳过] 未确认删除文件夹: {folder}")
                continue
            try:
                shutil.rmtree(folder)
                logger.info(f"[成功] 已删除文件夹: {folder}")
            except Exception as e:
                logger.error(f"[失败] 删除文件夹失败 {folder}: {e}")

def main():
    logger = setup_logger()
    logger.info("="*50)
    logger.info("开始执行清理任务...")

    # 1. 读取 YAML 配置
    if not CONFIG_FILE.exists():
        logger.error(f"配置文件不存在: {CONFIG_FILE}")
        sys.exit(1)

    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        logger.error(f"解析 YAML 配置文件失败: {e}")
        sys.exit(1)

    dry_run = config.get('dry_run', True)
    if dry_run:
        logger.warning(">>> 当前处于 DRY RUN (模拟运行) 模式，不会真正删除任何文件！<<<")

    # 2. 遍历规则并执行
    rules = config.get('cleanup_rules', [])
    if not rules:
        logger.warning("配置文件中没有定义任何清理规则。")
        return

    for rule in rules:
        if not validate_rule(rule, logger):
            continue
            
        item_type = rule.get('type', 'file')
        if item_type == 'file':
            process_file_rule(rule, dry_run, logger)
        elif item_type == 'folder':
            process_folder_rule(rule, dry_run, logger)
        else:
            logger.warning(f"未知的条目类型: {item_type}，已跳过。")

    logger.info("清理任务执行完毕。")
    logger.info("="*50)

if __name__ == "__main__":
    main()
