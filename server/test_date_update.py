#!/usr/bin/env python3
"""
测试日期修改上传功能
"""

import mysql.connector
from mysql.connector import Error
import json
from datetime import datetime

def test_date_update():
    """测试日期修改上传功能"""
    
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
        
        print("🔍 测试日期修改上传功能...")
        
        # 1. 获取一条记录进行测试
        cursor.execute("SELECT * FROM records WHERE deleted_at IS NULL LIMIT 1")
        original_record = cursor.fetchone()
        
        if not original_record:
            print("❌ 没有找到可测试的记录")
            return False
        
        record_id = original_record[0]
        original_date = original_record[2]
        print(f"📝 测试记录ID: {record_id}")
        print(f"   原始日期: {original_date}")
        
        # 2. 模拟Flutter应用的日期修改（修改为明天）
        new_date = datetime(2026, 2, 26, 12, 0, 0)  # 明天的日期
        
        # 模拟Flutter应用的UPDATE查询（包含日期字段）
        update_query = '''
            UPDATE records 
            SET date = %s, work_content = %s
            WHERE id = %s
        '''
        
        print(f"🔧 执行日期UPDATE查询:")
        print(f"   SQL: {update_query}")
        print(f"   参数: date={new_date}, work_content='测试日期修改', id={record_id}")
        
        cursor.execute(update_query, [
            new_date,
            '测试日期修改',
            record_id
        ])
        
        connection.commit()
        print("✅ UPDATE查询执行成功")
        
        # 3. 验证日期修改是否生效
        cursor.execute("SELECT * FROM records WHERE id = %s", [record_id])
        updated_record = cursor.fetchone()
        
        print(f"📊 验证日期修改结果:")
        print(f"   修改前日期: {original_date}")
        print(f"   修改后日期: {updated_record[2]}")
        
        # 检查日期修改是否成功
        if updated_record[2] == new_date:
            print("✅ 日期修改上传功能正常")
        else:
            print("❌ 日期修改上传功能异常")
            print(f"   期望日期: {new_date}")
            print(f"   实际日期: {updated_record[2]}")
            
        # 4. 恢复原始数据
        restore_query = '''
            UPDATE records 
            SET date = %s, work_content = %s
            WHERE id = %s
        '''
        
        cursor.execute(restore_query, [
            original_date,
            original_record[4],  # 原始工作内容
            record_id
        ])
        
        connection.commit()
        print("🔄 已恢复原始数据")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 测试失败: {e}")
        return False

def check_date_format():
    """检查日期格式兼容性"""
    
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
        
        print("\n🔍 检查日期格式兼容性...")
        
        # 检查数据库中的日期格式
        cursor.execute("SELECT id, date FROM records LIMIT 3")
        date_samples = cursor.fetchall()
        
        print("   数据库中的日期格式:")
        for record_id, date_val in date_samples:
            print(f"     记录ID {record_id}: 日期 = {date_val} (类型: {type(date_val).__name__})")
        
        # 测试Flutter应用使用的ISO日期格式
        test_iso_date = "2026-02-25T12:00:00.000Z"
        print(f"\n   测试Flutter应用的ISO日期格式: {test_iso_date}")
        
        # 检查MySQL是否接受ISO格式
        try:
            cursor.execute("SELECT STR_TO_DATE(%s, '%%Y-%%m-%%dT%%H:%%i:%%s.%%fZ')", [test_iso_date])
            mysql_date = cursor.fetchone()[0]
            print(f"   MySQL解析结果: {mysql_date}")
            print("   ✅ MySQL支持ISO日期格式")
        except Error as e:
            print(f"   ❌ MySQL不支持ISO日期格式: {e}")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 日期格式检查失败: {e}")
        return False

if __name__ == "__main__":
    print("🔧 日期修改上传功能测试")
    print("=" * 50)
    
    # 测试日期修改功能
    if test_date_update():
        # 检查日期格式兼容性
        check_date_format()
    
    print("\n✨ 测试完成！")