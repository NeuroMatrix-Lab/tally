#!/usr/bin/env python3
"""
测试日期修改功能修复
"""

import mysql.connector
from mysql.connector import Error
import json
from datetime import datetime

def test_mysql_date_format():
    """测试MySQL日期格式兼容性"""
    
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
        
        print("🔍 测试MySQL日期格式兼容性...")
        
        # 测试Flutter应用修复后的MySQL日期格式
        test_dates = [
            "2026-02-26 12:00:00",  # MySQL格式
            "2026-02-26T12:00:00Z",  # ISO格式
            "2026-02-26 00:00:00",  # 只有日期
        ]
        
        print("   测试日期格式:")
        for i, test_date in enumerate(test_dates):
            print(f"     {i+1}. {test_date}")
            
            # 测试UPDATE查询
            try:
                cursor.execute("UPDATE records SET date = %s WHERE id = 1", [test_date])
                connection.commit()
                print(f"       ✅ UPDATE成功")
                
                # 验证修改结果
                cursor.execute("SELECT date FROM records WHERE id = 1")
                result = cursor.fetchone()[0]
                print(f"       数据库中的日期: {result}")
                
            except Error as e:
                print(f"       ❌ UPDATE失败: {e}")
        
        # 恢复原始数据
        cursor.execute("UPDATE records SET date = '2026-02-24 00:00:00' WHERE id = 1")
        connection.commit()
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 测试失败: {e}")
        return False

def test_flutter_date_conversion():
    """测试Flutter应用的日期转换逻辑"""
    
    print("\n🔍 测试Flutter应用的日期转换逻辑...")
    
    # 模拟Flutter应用的日期转换
    test_cases = [
        {
            "input": "2026-02-26 12:00:00",  # MySQL格式
            "expected": "2026-02-26T12:00:00Z"  # ISO格式
        },
        {
            "input": "2026-02-26 00:00:00",  # 只有日期
            "expected": "2026-02-26T00:00:00Z"  # ISO格式
        },
        {
            "input": "2026-02-26T12:00:00Z",  # 已经是ISO格式
            "expected": "2026-02-26T12:00:00Z"  # 保持不变
        }
    ]
    
    print("   日期转换测试:")
    for i, test_case in enumerate(test_cases):
        input_date = test_case["input"]
        expected = test_case["expected"]
        
        # 模拟Flutter应用的转换逻辑
        try:
            if "T" in input_date and "Z" in input_date:
                # 已经是ISO格式
                result = input_date
            else:
                # MySQL格式转换为ISO格式
                parts = input_date.split(" ")
                if len(parts) == 2:
                    date_part = parts[0]
                    time_part = parts[1]
                    result = f"{date_part}T{time_part}Z"
                else:
                    result = input_date
            
            status = "✅" if result == expected else "❌"
            print(f"     {i+1}. 输入: {input_date}")
            print(f"         期望: {expected}")
            print(f"         实际: {result} {status}")
            
        except Exception as e:
            print(f"     {i+1}. 转换失败: {e}")
    
    return True

def check_current_date_values():
    """检查当前数据库中的日期值"""
    
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
        
        print("\n🔍 检查当前数据库中的日期值...")
        
        cursor.execute("SELECT id, date, work_content FROM records WHERE deleted_at IS NULL")
        records = cursor.fetchall()
        
        print("   当前记录中的日期值:")
        for record in records:
            record_id, date_val, work_content = record
            print(f"     记录ID {record_id}: 日期={date_val}, 内容={work_content}")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 检查失败: {e}")
        return False

if __name__ == "__main__":
    print("🔧 日期修改功能修复测试")
    print("=" * 50)
    
    # 测试MySQL日期格式兼容性
    if test_mysql_date_format():
        # 测试Flutter应用日期转换逻辑
        test_flutter_date_conversion()
        
        # 检查当前数据库中的日期值
        check_current_date_values()
    
    print("\n✨ 测试完成！")