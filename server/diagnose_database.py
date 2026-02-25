#!/usr/bin/env python3
"""
数据库服务诊断脚本
检查数据库连接状态和可能的服务问题
"""

import mysql.connector
from mysql.connector import Error
import subprocess
import time

def test_database_connection():
    """测试数据库连接"""
    
    config = {
        'host': '120.220.73.186',
        'port': 7378,
        'user': 'tally_user',
        'password': 'tally_password',
        'database': 'tally_db',
        'charset': 'utf8mb4'
    }
    
    try:
        print("🔍 测试数据库连接...")
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor()
        
        print("✅ 数据库连接成功！")
        
        # 检查表状态
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print("📋 数据库中的表:")
        for table in tables:
            print(f"   - {table[0]}")
        
        # 检查记录数量
        cursor.execute("SELECT COUNT(*) FROM records")
        record_count = cursor.fetchone()[0]
        print(f"📊 记录数量: {record_count}")
        
        # 检查最新的记录
        cursor.execute("SELECT * FROM records ORDER BY id DESC LIMIT 3")
        recent_records = cursor.fetchall()
        print(f"📝 最新3条记录:")
        for record in recent_records:
            print(f"   - ID: {record[0]}, 内容: {record[4]}, 金额: {record[5]}")
        
        # 检查表结构
        print("\n🔧 检查records表结构:")
        cursor.execute("DESCRIBE records")
        columns = cursor.fetchall()
        for column in columns:
            print(f"   - {column[0]}: {column[1]}")
        
        cursor.close()
        connection.close()
        
        return True, record_count
        
    except Error as e:
        print(f"❌ 数据库连接失败: {e}")
        return False, 0

def check_database_health():
    """检查数据库健康状态"""
    
    config = {
        'host': '120.220.73.186',
        'port': 7378,
        'user': 'tally_user',
        'password': 'tally_password',
        'database': 'tally_db',
        'charset': 'utf8mb4'
    }
    
    try:
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor()
        
        # 检查数据库状态
        cursor.execute("SHOW STATUS LIKE 'Threads_connected'")
        threads = cursor.fetchone()
        print(f"🔗 当前连接线程数: {threads[1]}")
        
        cursor.execute("SHOW STATUS LIKE 'Uptime'")
        uptime = cursor.fetchone()
        print(f"⏰ 数据库运行时间: {int(uptime[1]) // 3600} 小时 {int(uptime[1]) % 3600 // 60} 分钟")
        
        # 检查表大小
        cursor.execute("""
            SELECT table_name, 
                   ROUND((data_length + index_length) / 1024 / 1024, 2) as size_mb
            FROM information_schema.tables 
            WHERE table_schema = 'tally_db'
            ORDER BY size_mb DESC
        """)
        table_sizes = cursor.fetchall()
        print("📏 表大小统计:")
        for table in table_sizes:
            print(f"   - {table[0]}: {table[1]} MB")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 数据库健康检查失败: {e}")
        return False

def check_possible_issues():
    """检查可能的问题"""
    
    print("\n🔧 检查可能的问题...")
    
    # 检查网络连接
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex(('120.220.73.186', 7378))
        sock.close()
        
        if result == 0:
            print("✅ 网络端口连接正常")
        else:
            print("❌ 网络端口连接失败")
            print("💡 可能的问题: 防火墙阻止、Docker容器停止、网络问题")
            
    except Exception as e:
        print(f"❌ 网络检查失败: {e}")

def test_insert_record():
    """测试插入新记录"""
    
    config = {
        'host': '120.220.73.186',
        'port': 7378,
        'user': 'tally_user',
        'password': 'tally_password',
        'database': 'tally_db',
        'charset': 'utf8mb4'
    }
    
    try:
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor()
        
        print("\n🧪 测试插入新记录...")
        
        # 插入测试记录
        test_record = {
            'record_id': f'test_{int(time.time())}',
            'date': '2024-01-01 12:00:00',
            'category': '测试',
            'work_content': '诊断测试记录',
            'amount': 100.0,
            'ledger': '日常账本',
            'image_url': None,
            'staff_ids': '[]'
        }
        
        cursor.execute("""
            INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            test_record['record_id'],
            test_record['date'],
            test_record['category'],
            test_record['work_content'],
            test_record['amount'],
            test_record['ledger'],
            test_record['image_url'],
            test_record['staff_ids']
        ))
        
        connection.commit()
        print("✅ 测试记录插入成功")
        
        # 删除测试记录
        cursor.execute("DELETE FROM records WHERE record_id LIKE 'test_%'")
        connection.commit()
        print("✅ 测试记录清理完成")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 插入记录测试失败: {e}")
        return False

def check_docker_status():
    """检查Docker容器状态（模拟）"""
    
    print("\n🐳 Docker容器状态检查:")
    print("💡 请登录到服务器检查Docker容器状态:")
    print("   docker ps -a")
    print("   docker logs <container_name>")
    print("   docker stats")
    print("   systemctl status docker")

if __name__ == "__main__":
    print("🔧 数据库服务诊断工具")
    print("=" * 50)
    
    # 测试数据库连接
    connection_ok, record_count = test_database_connection()
    
    if connection_ok:
        # 检查数据库健康状态
        health_ok = check_database_health()
        
        # 测试插入记录
        insert_ok = test_insert_record()
        
        # 检查可能的问题
        check_possible_issues()
        
        # 检查Docker状态
        check_docker_status()
        
        print("\n📊 诊断总结:")
        print(f"   ✅ 数据库连接: {'正常' if connection_ok else '异常'}")
        print(f"   ✅ 数据库健康: {'正常' if health_ok else '异常'}")
        print(f"   ✅ 插入操作: {'正常' if insert_ok else '异常'}")
        print(f"   📝 当前记录数: {record_count}")
        
        if connection_ok and health_ok and insert_ok:
            print("\n🎉 数据库服务运行正常！")
        else:
            print("\n⚠️ 数据库服务存在一些问题，请检查上述日志")
    else:
        print("\n❌ 数据库连接失败，请检查:")
        print("   1. Docker容器是否运行")
        print("   2. 网络连接是否正常")
        print("   3. 防火墙设置")
        print("   4. 数据库服务状态")
    
    print("\n✨ 诊断完成！")