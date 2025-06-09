#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Web应用模块
提供Web界面管理监控系统
"""

from flask import Flask, render_template, jsonify, request, redirect, url_for, flash
from flask_cors import CORS
import logging
from datetime import datetime

def create_app(config, monitor):
    """创建Flask应用"""
    app = Flask(__name__, template_folder=str(config.project_root / 'templates'))
    app.secret_key = 'crypto_monitor_secret_key_2024'
    
    # 启用CORS
    CORS(app)
    
    # 配置日志
    if not config.debug_mode:
        logging.getLogger('werkzeug').setLevel(logging.WARNING)
    
    @app.route('/')
    def index():
        """主页"""
        status = monitor.get_status()
        return render_template('index.html', status=status)
    
    @app.route('/api/status')
    def api_status():
        """获取监控状态API"""
        return jsonify(monitor.get_status())
    
    @app.route('/api/statistics')
    def api_statistics():
        """获取统计信息API"""
        stats = monitor.db.get_statistics()
        return jsonify(stats)
    
    @app.route('/api/price-changes')
    def api_price_changes():
        """获取价格变动记录API"""
        limit = request.args.get('limit', 100, type=int)
        changes = monitor.db.get_recent_price_changes(limit)
        return jsonify(changes)
    
    @app.route('/api/announcements')
    def api_announcements():
        """获取公告记录API"""
        limit = request.args.get('limit', 50, type=int)
        announcements = monitor.db.get_recent_announcements(limit)
        return jsonify(announcements)
    
    @app.route('/api/new-listings')
    def api_new_listings():
        """获取新上币公告API"""
        limit = request.args.get('limit', 20, type=int)
        listings = monitor.db.get_new_listings(limit)
        return jsonify(listings)
    
    @app.route('/api/monitor/start', methods=['POST'])
    def api_start_monitor():
        """启动监控API"""
        try:
            monitor.start_monitoring()
            return jsonify({'success': True, 'message': '监控已启动'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/monitor/stop', methods=['POST'])
    def api_stop_monitor():
        """停止监控API"""
        try:
            monitor.stop_monitoring()
            return jsonify({'success': True, 'message': '监控已停止'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/monitor/price-check', methods=['POST'])
    def api_manual_price_check():
        """手动价格检查API"""
        try:
            result = monitor.manual_price_check()
            return jsonify(result)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/monitor/announcement-scan', methods=['POST'])
    def api_manual_announcement_scan():
        """手动公告扫描API"""
        try:
            result = monitor.manual_announcement_scan()
            return jsonify(result)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/config')
    def api_get_config():
        """获取配置API"""
        # 返回安全的配置信息（不包含敏感信息）
        safe_config = {
            'price_change_threshold': config.price_change_threshold,
            'price_check_interval': config.price_check_interval,
            'announcement_scan_interval': config.announcement_scan_interval,
            'proxy_enabled': config.proxy_enabled,
            'proxy_type': config.proxy_type,
            'nekobox_enabled': config.nekobox_enabled,
            'nekobox_auto_detect': config.nekobox_config.get('auto_detect', True),
            'exchanges': {
                name: {'enabled': ex_config.get('enabled', False)}
                for name, ex_config in config.exchanges.items()
            },
            'telegram_enabled': config.telegram_config.get('enabled', False)
        }
        return jsonify(safe_config)
    
    @app.route('/api/config', methods=['POST'])
    def api_update_config():
        """更新配置API"""
        try:
            data = request.get_json()
            
            # 更新配置
            if 'price_change_threshold' in data:
                config.set('price_change_threshold', float(data['price_change_threshold']))
            
            if 'price_check_interval' in data:
                config.set('price_check_interval', int(data['price_check_interval']))
            
            if 'announcement_scan_interval' in data:
                config.set('announcement_scan_interval', int(data['announcement_scan_interval']))
            
            if 'proxy_enabled' in data:
                config.set('proxy.enabled', bool(data['proxy_enabled']))
            
            if 'proxy_type' in data:
                config.set('proxy.type', data['proxy_type'])
            
            if 'nekobox_enabled' in data:
                config.set('proxy.nekobox.enabled', bool(data['nekobox_enabled']))
            
            if 'nekobox_auto_detect' in data:
                config.set('proxy.nekobox.auto_detect', bool(data['nekobox_auto_detect']))
            
            if 'exchanges' in data:
                for exchange, settings in data['exchanges'].items():
                    if 'enabled' in settings:
                        config.set(f'exchanges.{exchange}.enabled', bool(settings['enabled']))
            
            # 保存配置
            config.save()
            
            return jsonify({'success': True, 'message': '配置已更新'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/telegram/test', methods=['POST'])
    def api_test_telegram():
        """测试Telegram连接API"""
        try:
            result = monitor.notification_manager.test_telegram_connection()
            return jsonify(result)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/telegram/config', methods=['POST'])
    def api_update_telegram_config():
        """更新Telegram配置API"""
        try:
            data = request.get_json()
            
            if 'bot_token' in data:
                config.set('notifications.telegram.bot_token', data['bot_token'])
            
            if 'chat_id' in data:
                config.set('notifications.telegram.chat_id', data['chat_id'])
            
            if 'enabled' in data:
                config.set('notifications.telegram.enabled', bool(data['enabled']))
            
            if 'price_notify' in data:
                config.set('notifications.telegram.price_notify', bool(data['price_notify']))
            
            if 'announcement_notify' in data:
                config.set('notifications.telegram.announcement_notify', bool(data['announcement_notify']))
            
            if 'min_price_change' in data:
                config.set('notifications.telegram.min_price_change', float(data['min_price_change']))
            
            # 保存配置
            config.save()
            
            return jsonify({'success': True, 'message': 'Telegram配置已更新'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/dashboard')
    def dashboard():
        """仪表板页面"""
        return render_template('dashboard.html')
    
    @app.route('/settings')
    def settings():
        """设置页面"""
        return render_template('settings.html')
    
    @app.route('/logs')
    def logs():
        """日志页面"""
        return render_template('logs.html')
    
    @app.route('/api/nekobox/status')
    def api_nekobox_status():
        """获取Nekobox状态API"""
        try:
            from app.core.nekobox_proxy import NekoboxProxyManager
            nekobox_manager = NekoboxProxyManager()
            status = nekobox_manager.get_status()
            return jsonify(status)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/nekobox/detect', methods=['POST'])
    def api_nekobox_detect():
        """检测Nekobox代理API"""
        try:
            from app.core.nekobox_proxy import NekoboxProxyManager
            nekobox_manager = NekoboxProxyManager()
            result = nekobox_manager.refresh_detection()
            return jsonify(result)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/nekobox/test', methods=['POST'])
    def api_nekobox_test():
        """测试Nekobox代理连接API"""
        try:
            data = request.get_json()
            proxy_url = data.get('proxy_url')
            
            if not proxy_url:
                return jsonify({'success': False, 'message': '缺少代理URL'}), 400
            
            from app.core.nekobox_proxy import NekoboxProxyManager
            nekobox_manager = NekoboxProxyManager()
            result = nekobox_manager.test_proxy_connection(proxy_url)
            return jsonify(result)
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.route('/api/nekobox/config', methods=['POST'])
    def api_update_nekobox_config():
        """更新Nekobox配置API"""
        try:
            data = request.get_json()
            
            if 'enabled' in data:
                config.set('proxy.nekobox.enabled', bool(data['enabled']))
            
            if 'auto_detect' in data:
                config.set('proxy.nekobox.auto_detect', bool(data['auto_detect']))
            
            if 'manual_config' in data:
                manual_config = data['manual_config']
                if 'host' in manual_config:
                    config.set('proxy.nekobox.manual_config.host', manual_config['host'])
                if 'port' in manual_config:
                    config.set('proxy.nekobox.manual_config.port', int(manual_config['port']))
                if 'protocol' in manual_config:
                    config.set('proxy.nekobox.manual_config.protocol', manual_config['protocol'])
            
            # 保存配置
            config.save()
            
            return jsonify({'success': True, 'message': 'Nekobox配置已更新'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': 'Not Found'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({'error': 'Internal Server Error'}), 500
    
    return app

