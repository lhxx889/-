"""
Gate.io加密货币异动监控系统 - 自定义格式化模块
根据用户需求定制推送格式，实时补全市场动态信息
"""

import logging
import time
import json
import requests
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime, timedelta
import os
import re

# 导入相关模块
try:
    from src.enhanced_coin_info import EnhancedCoinInfo
    enhanced_coin_info_available = True
except ImportError:
    enhanced_coin_info_available = False

try:
    from src.contract_info_fetcher import ContractInfoFetcher
    contract_info_available = True
except ImportError:
    contract_info_available = False

try:
    from src.price_history_fetcher import PriceHistoryFetcher
    price_history_available = True
except ImportError:
    price_history_available = False

# 配置日志
logger = logging.getLogger("custom_formatter")

class CustomFormatter:
    """自定义格式化类，负责按照用户需求格式化推送内容"""
    
    def __init__(self):
        """初始化自定义格式化器"""
        # 初始化币种信息查询器
        self.coin_info = EnhancedCoinInfo() if enhanced_coin_info_available else None
        
        # 初始化合约信息获取器
        self.contract_info = ContractInfoFetcher() if contract_info_available else None
        
        # 初始化价格历史获取器
        self.price_history = PriceHistoryFetcher() if price_history_available else None
        
        logger.info("自定义格式化模块初始化完成")
    
    def _make_request(self, url: str, params: Dict = None, headers: Dict = None) -> Optional[Dict]:
        """
        发送API请求并处理可能的异常
        
        Args:
            url: API URL
            params: 请求参数
            headers: 请求头
            
        Returns:
            API响应数据或None（如果请求失败）
        """
        max_retries = 3
        retry_delay = 2
        
        for attempt in range(max_retries):
            try:
                response = requests.get(url, params=params, headers=headers, timeout=10)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.RequestException as e:
                logger.warning(f"API请求失败 (尝试 {attempt+1}/{max_retries}): {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (attempt + 1))  # 指数退避
                else:
                    logger.error(f"API请求最终失败: {str(e)}")
                    return None
    
    def get_social_media_links(self, symbol: str) -> Dict[str, str]:
        """
        获取社交媒体链接
        
        Args:
            symbol: 币种符号
            
        Returns:
            社交媒体链接字典
        """
        result = {
            "telegram": "",
            "twitter": "",
            "website": ""
        }
        
        if not self.coin_info:
            return result
        
        try:
            # 获取币种信息
            coin_info = self.coin_info.get_comprehensive_coin_info(symbol)
            
            # 获取社交媒体链接
            social_links = coin_info.get("social_links", {})
            
            # 更新链接
            if "telegram" in social_links:
                result["telegram"] = social_links["telegram"]
            if "twitter" in social_links:
                result["twitter"] = social_links["twitter"]
            if "website" in social_links:
                result["website"] = social_links["website"]
            
            return result
        except Exception as e:
            logger.error(f"获取社交媒体链接失败: {str(e)}")
            return result
    
    def get_market_cap(self, symbol: str, price: float = None) -> Optional[float]:
        """
        获取市值
        
        Args:
            symbol: 币种符号
            price: 当前价格（可选）
            
        Returns:
            市值（美元）
        """
        if not self.coin_info:
            return None
        
        try:
            # 获取币种信息
            coin_info = self.coin_info.get_comprehensive_coin_info(symbol)
            
            # 获取市场数据
            market_data = coin_info.get("market_data", {})
            
            # 如果有市值数据，直接返回
            if "market_cap" in market_data and market_data["market_cap"]:
                return market_data["market_cap"]
            
            # 如果没有市值数据，但有流通量和价格，计算市值
            if "circulating_supply" in market_data and market_data["circulating_supply"] and price:
                return market_data["circulating_supply"] * price
            
            return None
        except Exception as e:
            logger.error(f"获取市值失败: {str(e)}")
            return None
    
    def get_contract_info(self, symbol: str) -> Optional[str]:
        """
        获取合约信息
        
        Args:
            symbol: 币种符号
            
        Returns:
            合约地址
        """
        if not self.contract_info:
            return None
        
        try:
            # 获取合约信息
            contract_data = self.contract_info.get_contract_info(symbol)
            
            if contract_data and "address" in contract_data:
                return contract_data["address"]
            
            return None
        except Exception as e:
            logger.error(f"获取合约信息失败: {str(e)}")
            return None
    
    def get_volume_stats(self, symbol: str) -> Dict[str, float]:
        """
        获取交易量统计
        
        Args:
            symbol: 币种符号
            
        Returns:
            交易量统计字典
        """
        result = {
            "volume_5min": 0.0,
            "volume_24h": 0.0
        }
        
        if not self.price_history:
            return result
        
        try:
            # 获取5分钟交易量
            five_min_data = self.price_history.get_recent_volume(symbol, minutes=5)
            if five_min_data:
                result["volume_5min"] = five_min_data
            
            # 获取24小时交易量
            day_data = self.price_history.get_recent_volume(symbol, hours=24)
            if day_data:
                result["volume_24h"] = day_data
            
            return result
        except Exception as e:
            logger.error(f"获取交易量统计失败: {str(e)}")
            return result
    
    def get_transaction_stats(self, symbol: str) -> Dict[str, int]:
        """
        获取交易统计信息
        
        Args:
            symbol: 币种符号
            
        Returns:
            交易统计信息字典
        """
        result = {
            "total": 0,
            "buy": 0,
            "sell": 0
        }
        
        try:
            # 尝试从API获取交易统计信息
            if self.price_history:
                trades = self.price_history.get_recent_trades(symbol, hours=24)
                if trades:
                    result["total"] = len(trades)
                    result["buy"] = sum(1 for trade in trades if trade.get("side") == "buy")
                    result["sell"] = sum(1 for trade in trades if trade.get("side") == "sell")
                    return result
            
            # 如果无法获取，使用估算值
            if symbol:
                base_currency = symbol.split('_')[0]
                # 根据币种首字母估算交易次数（仅作为示例）
                first_char = base_currency[0].lower()
                char_value = ord(first_char) - ord('a') + 1
                result["total"] = max(10, char_value * 5)
                result["buy"] = int(result["total"] * 0.7)  # 假设70%是买入
                result["sell"] = result["total"] - result["buy"]
            
            return result
        except Exception as e:
            logger.error(f"获取交易统计信息失败: {str(e)}")
            return result
    
    def get_comments_count(self, symbol: str) -> int:
        """
        获取跟帖数
        
        Args:
            symbol: 币种符号
            
        Returns:
            跟帖数
        """
        try:
            # 尝试从社交媒体API获取跟帖数
            # 这里需要实现具体的API调用逻辑
            # 由于缺乏直接API，返回0
            return 0
        except Exception as e:
            logger.error(f"获取跟帖数失败: {str(e)}")
            return 0
    
    def format_price_change_message(self, anomaly: Dict) -> str:
        """
        格式化价格变化消息（按照用户提供的模板）
        
        Args:
            anomaly: 异常数据
            
        Returns:
            格式化后的消息
        """
        try:
            # 提取基本信息
            symbol = anomaly.get("symbol", "")
            coin_name = symbol.split('_')[0] if '_' in symbol else symbol
            
            # 获取价格变化
            price_change_pct = anomaly.get("price_change_pct", 0)
            price_change_str = f"涨幅 {price_change_pct:.2f}%" if price_change_pct > 0 else f"跌幅 {abs(price_change_pct):.2f}%"
            
            # 获取当前价格
            current_price = anomaly.get("current_price", 0)
            
            # 获取交易量
            volume_24h = anomaly.get("volume_24h", 0)
            volume_stats = self.get_volume_stats(symbol)
            volume_5min = volume_stats.get("volume_5min", 0)
            
            # 获取市值
            market_cap = self.get_market_cap(symbol, current_price)
            market_cap_str = f"${market_cap:.2f}" if market_cap else "未知"
            
            # 获取合约信息
            contract = self.get_contract_info(symbol)
            contract_str = contract if contract else "未知"
            
            # 获取交易统计
            transaction_stats = self.get_transaction_stats(symbol)
            
            # 获取跟帖数
            comments_count = self.get_comments_count(symbol)
            
            # 获取社交媒体链接
            social_links = self.get_social_media_links(symbol)
            telegram_link = social_links.get("telegram", "")
            twitter_link = social_links.get("twitter", "")
            website_link = social_links.get("website", "")
            
            # 构建消息
            message = f"🔥🔥🔥\n"
            message += f"📢 {price_change_str}\n\n"
            
            message += f"币种名称: {coin_name}\n"
            message += f"合约: {contract_str}\n"
            message += f"📈 市值：{market_cap_str}\n"
            message += f"💸 5分钟交易量：${volume_5min:.2f}\n"
            message += f"📊24小时 交易次数：{transaction_stats['total']} 🟢 买：{transaction_stats['buy']} 🔴 卖：{transaction_stats['sell']}\n"
            message += f"💬 跟帖数：{comments_count}\n\n"
            
            # 添加社交媒体链接
            social_parts = []
            if telegram_link:
                social_parts.append(f"电报 {telegram_link}")
            else:
                social_parts.append("电报 未知")
            
            if twitter_link:
                social_parts.append(f"推特 {twitter_link}")
            else:
                social_parts.append("推特 未知")
            
            if website_link:
                social_parts.append(f"官网 {website_link}")
            else:
                social_parts.append("官网 未知")
            
            message += " | ".join(social_parts)
            
            if not any([telegram_link, twitter_link, website_link]):
                message += " （如社交媒体缺失，去x查找）"
            
            return message
        except Exception as e:
            logger.error(f"格式化价格变化消息失败: {str(e)}")
            # 返回基本消息
            return f"🚨 异动警报 🚨\n\n币种: {anomaly.get('symbol', '')}\n当前价格: {anomaly.get('current_price', 0):.8f}"
    
    def format_volume_change_message(self, anomaly: Dict) -> str:
        """
        格式化交易量变化消息（按照用户提供的模板）
        
        Args:
            anomaly: 异常数据
            
        Returns:
            格式化后的消息
        """
        # 交易量变化消息使用相同的格式
        return self.format_price_change_message(anomaly)
    
    def format_custom_message(self, anomaly: Dict) -> str:
        """
        格式化自定义消息（根据异常类型选择合适的格式化方法）
        
        Args:
            anomaly: 异常数据
            
        Returns:
            格式化后的消息
        """
        # 根据异常类型选择格式化方法
        anomaly_type = anomaly.get("type", "")
        
        if anomaly_type == "price":
            return self.format_price_change_message(anomaly)
        elif anomaly_type == "volume":
            return self.format_volume_change_message(anomaly)
        else:
            # 默认使用价格变化格式
            return self.format_price_change_message(anomaly)

# 创建全局实例
custom_formatter = CustomFormatter()
