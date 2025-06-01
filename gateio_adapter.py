"""
Gate.io和币安加密货币异动监控系统 - Gate.io适配器
将现有Gate.io数据采集模块适配为交易所接口实现
"""

import logging
import time
from typing import Dict, List, Any, Optional
from datetime import datetime

# 导入交易所接口
from src.exchanges.exchange_interface import ExchangeInterface
# 导入原有的Gate.io数据采集模块
from src.data_collector import DataCollector

# 配置日志
logger = logging.getLogger("gateio_adapter")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(levelname)s:%(name)s:%(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

class GateioAdapter(ExchangeInterface):
    """Gate.io适配器，将现有数据采集模块封装为交易所接口实现"""
    
    def __init__(self, api_key: str = "", api_secret: str = "", cache_duration: int = 300):
        """
        初始化Gate.io适配器
        
        Args:
            api_key: API密钥
            api_secret: API密钥
            cache_duration: 缓存有效期（秒）
        """
        super().__init__(api_key, api_secret, cache_duration)
        
        # 初始化原有的数据采集器
        self.collector = DataCollector(api_key, api_secret)
        
        # 缓存
        self.cache = {}
        self.cache_time = {}
        
        logger.info("Gate.io适配器初始化完成")
    
    @property
    def exchange_name(self) -> str:
        """获取交易所名称"""
        return "Gate.io"
    
    @property
    def rate_limits(self) -> Dict[str, Any]:
        """获取API速率限制信息"""
        return {
            "weight_per_minute": 900,
            "orders_per_second": 5,
            "orders_per_day": 50000
        }
    
    def convert_to_standard_symbol(self, exchange_symbol: str) -> str:
        """
        将Gate.io特定的币种符号转换为标准格式
        
        Args:
            exchange_symbol: Gate.io特定的币种符号
            
        Returns:
            标准化的币种符号
        """
        # Gate.io的币种符号已经是标准格式（如"BTC_USDT"）
        return exchange_symbol
    
    def convert_from_standard_symbol(self, standard_symbol: str) -> str:
        """
        将标准格式的币种符号转换为Gate.io特定格式
        
        Args:
            standard_symbol: 标准化的币种符号
            
        Returns:
            Gate.io特定的币种符号
        """
        # 标准格式就是Gate.io格式
        return standard_symbol
    
    def standardize_ticker_data(self, raw_ticker: Dict) -> Dict:
        """
        将Gate.io原始ticker数据标准化为统一格式
        
        Args:
            raw_ticker: Gate.io原始ticker数据
            
        Returns:
            标准化的ticker数据
        """
        try:
            symbol = raw_ticker.get("currency_pair", "")
            
            return {
                "symbol": symbol,
                "exchange": self.exchange_name,
                "price": float(raw_ticker.get("last", 0)),
                "volume_24h": float(raw_ticker.get("base_volume", 0)),
                "change_24h": float(raw_ticker.get("change", 0)),
                "change_percentage_24h": float(raw_ticker.get("change_percentage", 0)),
                "high_24h": float(raw_ticker.get("high_24h", 0)),
                "low_24h": float(raw_ticker.get("low_24h", 0)),
                "timestamp": int(time.time() * 1000),
                "raw_data": raw_ticker
            }
        except Exception as e:
            logger.error(f"标准化ticker数据时出错: {str(e)}")
            return {}
    
    def fetch_all_tickers(self) -> List[Dict]:
        """
        获取所有币种的ticker数据
        
        Returns:
            标准化的ticker数据列表
        """
        # 检查缓存
        cache_key = "all_tickers"
        if cache_key in self.cache and time.time() - self.cache_time.get(cache_key, 0) < self.cache_duration:
            return self.cache[cache_key]
        
        logger.info("获取所有币种ticker数据")
        
        # 使用原有数据采集器获取数据
        raw_tickers = self.collector.get_cached_tickers()
        
        if not raw_tickers:
            logger.error("获取ticker数据失败")
            return []
        
        # 标准化数据
        standard_tickers = []
        for raw_ticker in raw_tickers:
            standard_ticker = self.standardize_ticker_data(raw_ticker)
            if standard_ticker:
                standard_tickers.append(standard_ticker)
        
        # 更新缓存
        self.cache[cache_key] = standard_tickers
        self.cache_time[cache_key] = time.time()
        
        logger.info(f"成功获取{len(standard_tickers)}个币种的ticker数据")
        return standard_tickers
    
    def fetch_ticker(self, symbol: str) -> Optional[Dict]:
        """
        获取特定币种的ticker数据
        
        Args:
            symbol: 标准化的币种符号（如"BTC_USDT"）
            
        Returns:
            标准化的ticker数据
        """
        # 检查缓存
        cache_key = f"ticker_{symbol}"
        if cache_key in self.cache and time.time() - self.cache_time.get(cache_key, 0) < self.cache_duration:
            return self.cache[cache_key]
        
        logger.info(f"获取{symbol}的ticker数据")
        
        # 使用原有数据采集器获取数据
        raw_ticker = self.collector.get_ticker(symbol)
        
        if not raw_ticker:
            logger.error(f"获取{symbol}的ticker数据失败")
            return None
        
        # 标准化数据
        standard_ticker = self.standardize_ticker_data(raw_ticker)
        
        # 更新缓存
        if standard_ticker:
            self.cache[cache_key] = standard_ticker
            self.cache_time[cache_key] = time.time()
        
        logger.info(f"成功获取{symbol}的ticker数据")
        return standard_ticker
    
    def fetch_historical_data(self, symbol: str, interval: str, limit: int) -> List[Dict]:
        """
        获取历史K线数据
        
        Args:
            symbol: 标准化的币种符号（如"BTC_USDT"）
            interval: 时间间隔（如"1h", "1d"）
            limit: 获取数量限制
            
        Returns:
            标准化的历史数据列表
        """
        # 检查缓存
        cache_key = f"history_{symbol}_{interval}_{limit}"
        if cache_key in self.cache and time.time() - self.cache_time.get(cache_key, 0) < self.cache_duration:
            return self.cache[cache_key]
        
        logger.info(f"获取{symbol}的历史数据，间隔:{interval}，数量:{limit}")
        
        # 使用原有数据采集器获取数据
        raw_data = self.collector.get_historical_data(symbol, interval, limit)
        
        if not raw_data:
            logger.error(f"获取{symbol}的历史数据失败")
            return []
        
        # 标准化数据
        standard_data = []
        for item in raw_data:
            standard_item = {
                "symbol": symbol,
                "exchange": self.exchange_name,
                "timestamp": item.get("timestamp", 0),
                "datetime": item.get("datetime", ""),
                "open": float(item.get("open", 0)),
                "high": float(item.get("high", 0)),
                "low": float(item.get("low", 0)),
                "close": float(item.get("close", 0)),
                "volume": float(item.get("volume", 0)),
                "raw_data": item
            }
            standard_data.append(standard_item)
        
        # 更新缓存
        if standard_data:
            self.cache[cache_key] = standard_data
            self.cache_time[cache_key] = time.time()
        
        logger.info(f"成功获取{symbol}的{len(standard_data)}条历史数据")
        return standard_data
    
    def get_all_tickers(self) -> List[Dict]:
        """
        兼容性方法，作为fetch_all_tickers的别名
        
        Returns:
            标准化的ticker数据列表
        """
        logger.info("通过兼容性方法get_all_tickers调用fetch_all_tickers")
        return self.fetch_all_tickers()
