#!/usr/bin/env python3
"""
调试Flutter前端数据获取问题
"""

import mysql.connector
from mysql.connector import Error
import json
from datetime import datetime

def debug_flutter_data_parsing():
    """模拟Flutter应用的数据解析过程"""
    
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
        
        print("🔍 模拟Flutter应用数据解析过程...")
        
        # 执行Flutter应用使用的查询
        cursor.execute('''
            SELECT * FROM records 
            WHERE deleted_at IS NULL 
            ORDER BY date DESC
        ''')
        results = cursor.fetchall()
        
        print(f"✅ 查询成功，返回 {len(results)} 条记录")
        
        # 模拟Flutter应用的数据解析
        for i, row in enumerate(results):
            print(f"\n📝 解析第 {i+1} 条记录:")
            
            # 模拟Flutter的row字段访问
            record_data = {
                'id': str(row[0]),  # row['id'].toString()
                'recordId': row[1],
                'date': row[2],     # row['date']
                'category': row[3],
                'workContent': row[4],
                'amount': row[5],
                'ledger': row[6],
                'imageUrl': row[7],
                'staffIds': row[8],
            }
            
            print(f"   原始数据: {record_data}")
            
            # 检查每个字段的类型
            print("   字段类型检查:")
            for key, value in record_data.items():
                print(f"     - {key}: {value} (类型: {type(value).__name__})")
            
            # 模拟Flutter的日期处理
            date_value = record_data['date']
            print(f"   日期字段处理:")
            print(f"     原始值: {date_value}")
            print(f"     类型: {type(date_value).__name__}")
            
            # 检查是否可以直接调用toIso8601String()
            if hasattr(date_value, 'toIso8601String'):
                print(f"     ⚠️ 可以调用toIso8601String()")
            else:
                print(f"     ❌ 不能调用toIso8601String() - 不是DateTime对象")
                
            # 检查日期字符串格式
            if isinstance(date_value, str):
                print(f"     📅 日期是字符串格式: {date_value}")
                # 尝试解析为ISO格式
                try:
                    parsed_date = datetime.fromisoformat(date_value.replace(' ', 'T'))
                    iso_date = parsed_date.isoformat()
                    print(f"     ✅ 可以解析为ISO格式: {iso_date}")
                except Exception as e:
                    print(f"     ❌ 解析失败: {e}")
            
            # 检查金额字段
            amount_value = record_data['amount']
            print(f"   金额字段处理:")
            print(f"     原始值: {amount_value}")
            print(f"     类型: {type(amount_value).__name__}")
            
            # 检查staff_ids字段
            staff_ids_value = record_data['staffIds']
            print(f"   staff_ids字段处理:")
            print(f"     原始值: {staff_ids_value}")
            print(f"     类型: {type(staff_ids_value).__name__}")
            
            if staff_ids_value and isinstance(staff_ids_value, str):
                try:
                    parsed_staff = json.loads(staff_ids_value)
                    print(f"     ✅ JSON解析成功: {parsed_staff}")
                except json.JSONDecodeError as e:
                    print(f"     ❌ JSON解析失败: {e}")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 数据库查询失败: {e}")
        return False

def check_mysql_connector_types():
    """检查MySQL连接器返回的数据类型"""
    
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
        
        print("\n🔍 检查MySQL连接器数据类型...")
        
        # 使用字典游标查看实际返回的数据类型
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM records LIMIT 1")
        result = cursor.fetchone()
        
        if result:
            print("   使用字典游标的字段类型:")
            for key, value in result.items():
                print(f"     - {key}: {value} (类型: {type(value).__name__})")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 数据类型检查失败: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Flutter前端数据获取问题调试")
    print("=" * 50)
    
    # 调试数据解析过程
    if debug_flutter_data_parsing():
        # 检查MySQL连接器数据类型
        check_mysql_connector_types()
    
    print("\n✨ 调试完成！")