#!/usr/bin/env python3
"""
测试Flutter应用数据库连接问题
"""

import mysql.connector
from mysql.connector import Error
import json

def test_flutter_queries():
    """测试Flutter应用使用的查询"""
    
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
        
        print("🔍 测试Flutter应用使用的查询...")
        
        # 1. 测试获取所有记录（getAllRecords）
        print("\n1. 测试获取所有记录:")
        cursor.execute('''
            SELECT * FROM records 
            WHERE deleted_at IS NULL 
            ORDER BY date DESC
        ''')
        all_records = cursor.fetchall()
        print(f"   ✅ 查询成功，返回 {len(all_records)} 条记录")
        
        if all_records:
            for i, record in enumerate(all_records[:3]):  # 显示前3条
                print(f"     记录 {i+1}: ID={record[0]}, 内容={record[4]}, 金额={record[5]}")
        
        # 2. 测试获取最近记录（getRecentRecords）
        print("\n2. 测试获取最近3个月记录:")
        cursor.execute('''
            SELECT * FROM records 
            WHERE deleted_at IS NULL 
            AND date >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
            ORDER BY date DESC
        ''')
        recent_records = cursor.fetchall()
        print(f"   ✅ 查询成功，返回 {len(recent_records)} 条记录")
        
        # 3. 检查表结构
        print("\n3. 检查records表结构:")
        cursor.execute("DESCRIBE records")
        columns = cursor.fetchall()
        print("   表结构:")
        for column in columns:
            print(f"     - {column[0]}: {column[1]}")
        
        # 4. 检查数据格式
        print("\n4. 检查数据格式:")
        if all_records:
            sample_record = all_records[0]
            print("   第一条记录的字段值:")
            for i, value in enumerate(sample_record):
                column_name = columns[i][0] if i < len(columns) else f"字段{i}"
                print(f"     - {column_name}: {value} (类型: {type(value).__name__})")
        
        # 5. 检查staff_ids字段格式（JSON格式）
        print("\n5. 检查staff_ids字段格式:")
        cursor.execute("SELECT id, staff_ids FROM records LIMIT 3")
        staff_ids_samples = cursor.fetchall()
        for record_id, staff_ids in staff_ids_samples:
            print(f"   记录ID {record_id}: staff_ids = {staff_ids}")
            if staff_ids:
                try:
                    parsed = json.loads(staff_ids)
                    print(f"      JSON解析成功: {parsed}")
                except json.JSONDecodeError as e:
                    print(f"      JSON解析失败: {e}")
        
        cursor.close()
        connection.close()
        
        print("\n✅ 所有查询测试完成！")
        
        # 诊断建议
        print("\n🔧 诊断建议:")
        if len(all_records) == 0:
            print("   ⚠️ 数据库中暂无记录，请先添加记录")
        else:
            print("   ✅ 数据库中有记录，问题可能出现在Flutter应用的数据解析")
            
        return True
        
    except Error as e:
        print(f"❌ 数据库查询失败: {e}")
        return False

def check_data_issues():
    """检查数据问题"""
    
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
        
        print("\n🔍 检查数据问题...")
        
        # 检查是否有空值问题
        cursor.execute("SELECT COUNT(*) FROM records WHERE category IS NULL OR work_content IS NULL OR amount IS NULL")
        null_count = cursor.fetchone()[0]
        if null_count > 0:
            print(f"   ⚠️ 发现 {null_count} 条记录存在空值字段")
        
        # 检查日期格式
        cursor.execute("SELECT id, date FROM records LIMIT 3")
        date_samples = cursor.fetchall()
        print("   日期格式检查:")
        for record_id, date_val in date_samples:
            print(f"     记录ID {record_id}: 日期 = {date_val} (类型: {type(date_val).__name__})")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 数据检查失败: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Flutter应用数据库连接问题诊断")
    print("=" * 50)
    
    # 测试Flutter查询
    if test_flutter_queries():
        # 检查数据问题
        check_data_issues()
    
    print("\n✨ 诊断完成！")