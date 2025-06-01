#!/usr/bin/env python3
"""
Gate.io和币安加密货币异动监控系统 - 兼容性补丁
用于修复方法名不匹配问题

使用方法:
1. 将此文件上传到系统根目录
2. 运行: python compatibility_patch.py
3. 重启监控系统: python main.py
"""

import os
import sys
import re
import logging
import shutil
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("patch.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("compatibility_patch")

class CompatibilityPatcher:
    """兼容性补丁应用器"""
    
    def __init__(self):
        """初始化补丁应用器"""
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.exchanges_dir = os.path.join(self.base_dir, "src", "exchanges")
        self.backup_dir = os.path.join(self.base_dir, "backup_" + datetime.now().strftime("%Y%m%d%H%M%S"))
        
        # 检查目录是否存在
        if not os.path.exists(self.exchanges_dir):
            logger.error(f"交易所模块目录不存在: {self.exchanges_dir}")
            sys.exit(1)
    
    def backup_files(self):
        """备份将要修改的文件"""
        logger.info("创建备份目录...")
        os.makedirs(self.backup_dir, exist_ok=True)
        os.makedirs(os.path.join(self.backup_dir, "src", "exchanges"), exist_ok=True)
        
        # 备份文件
        files_to_backup = [
            os.path.join(self.exchanges_dir, "gateio_adapter.py"),
            os.path.join(self.exchanges_dir, "exchange_manager.py")
        ]
        
        for file_path in files_to_backup:
            if os.path.exists(file_path):
                backup_path = file_path.replace(self.base_dir, self.backup_dir)
                logger.info(f"备份文件: {file_path} -> {backup_path}")
                shutil.copy2(file_path, backup_path)
    
    def patch_gateio_adapter(self):
        """修补Gate.io适配器"""
        file_path = os.path.join(self.exchanges_dir, "gateio_adapter.py")
        if not os.path.exists(file_path):
            logger.error(f"Gate.io适配器文件不存在: {file_path}")
            return False
        
        logger.info(f"修补Gate.io适配器: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否已经有get_all_tickers方法
        if "def get_all_tickers" in content:
            logger.info("Gate.io适配器已包含get_all_tickers方法，无需修补")
            return True
        
        # 查找fetch_all_tickers方法的位置
        fetch_method_pattern = re.compile(r'def fetch_all_tickers\(self.*?\):.*?(?=\n    def|\n\n|$)', re.DOTALL)
        match = fetch_method_pattern.search(content)
        
        if not match:
            logger.error("无法找到fetch_all_tickers方法，无法修补")
            return False
        
        # 在fetch_all_tickers方法后添加get_all_tickers别名方法
        get_all_tickers_method = '''
    def get_all_tickers(self):
        """
        兼容性方法，作为fetch_all_tickers的别名
        
        Returns:
            ticker数据列表
        """
        logger.info("通过兼容性方法get_all_tickers调用fetch_all_tickers")
        return self.fetch_all_tickers()
'''
        
        # 插入新方法
        insert_pos = match.end()
        new_content = content[:insert_pos] + get_all_tickers_method + content[insert_pos:]
        
        # 写回文件
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        logger.info("成功修补Gate.io适配器，添加了get_all_tickers方法")
        return True
    
    def patch_exchange_manager(self):
        """修补交易所管理器"""
        file_path = os.path.join(self.exchanges_dir, "exchange_manager.py")
        if not os.path.exists(file_path):
            logger.error(f"交易所管理器文件不存在: {file_path}")
            return False
        
        logger.info(f"修补交易所管理器: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否已经有get_latest_price_data方法
        if "def get_latest_price_data" in content:
            logger.info("交易所管理器已包含get_latest_price_data方法，无需修补")
            return True
        
        # 查找类定义的结束位置
        class_pattern = re.compile(r'class ExchangeManager.*?(?=\n# 如果是主模块|\n\n\n|$)', re.DOTALL)
        match = class_pattern.search(content)
        
        if not match:
            logger.error("无法找到ExchangeManager类定义，无法修补")
            return False
        
        # 添加get_latest_price_data方法
        get_latest_price_data_method = '''
    def get_latest_price_data(self, symbol=None):
        """
        获取最新价格数据，兼容原有接口
        
        Args:
            symbol: 币种符号，如果为None则返回所有币种数据
            
        Returns:
            最新价格数据字典
        """
        logger.info("调用兼容性方法get_latest_price_data")
        exchange = self._select_exchange()
        if not exchange:
            logger.error("无法选择可用的交易所")
            return {}
        
        try:
            # 获取所有ticker数据
            if hasattr(exchange, 'get_all_tickers'):
                tickers = exchange.get_all_tickers()
            else:
                tickers = exchange.fetch_all_tickers()
            
            # 转换为原有格式
            data = {}
            for ticker in tickers:
                symbol_key = ticker.get("symbol", "")
                if not symbol_key:
                    continue
                    
                if symbol and symbol != symbol_key:
                    continue
                    
                data[symbol_key] = {
                    "price": ticker.get("price", 0),
                    "volume_24h": ticker.get("volume_24h", 0),
                    "change_percentage_24h": ticker.get("change_percentage_24h", 0),
                    "timestamp": ticker.get("timestamp", "")
                }
            
            return data
        except Exception as e:
            logger.error(f"获取最新价格数据失败: {str(e)}")
            return {}
'''
        
        # 插入新方法
        insert_pos = match.end()
        new_content = content[:insert_pos] + get_latest_price_data_method + content[insert_pos:]
        
        # 写回文件
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        logger.info("成功修补交易所管理器，添加了get_latest_price_data方法")
        return True
    
    def apply_patches(self):
        """应用所有补丁"""
        logger.info("开始应用兼容性补丁...")
        
        # 备份文件
        self.backup_files()
        
        # 修补Gate.io适配器
        gateio_patched = self.patch_gateio_adapter()
        
        # 修补交易所管理器
        manager_patched = self.patch_exchange_manager()
        
        if gateio_patched and manager_patched:
            logger.info("所有补丁应用成功！")
            logger.info(f"原始文件已备份到: {self.backup_dir}")
            logger.info("请重启监控系统以使更改生效: python main.py")
            return True
        else:
            logger.error("补丁应用过程中发生错误，请检查日志")
            return False


if __name__ == "__main__":
    print("=" * 60)
    print("Gate.io和币安加密货币异动监控系统 - 兼容性补丁")
    print("=" * 60)
    
    patcher = CompatibilityPatcher()
    success = patcher.apply_patches()
    
    if success:
        print("\n补丁应用成功！系统现在应该可以正常工作了。")
        print("请重启监控系统: python main.py")
    else:
        print("\n补丁应用过程中发生错误，请检查patch.log文件获取详细信息。")
    
    print("=" * 60)
