#!/usr/bin/env python3
"""
测试修改账目上传功能
"""

import mysql.connector
from mysql.connector import Error
import json
from datetime import datetime

def test_update_record():
    """测试更新记录功能"""
    
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
        
        print("🔍 测试修改账目上传功能...")
        
        # 1. 获取一条记录进行测试
        cursor.execute("SELECT * FROM records WHERE deleted_at IS NULL LIMIT 1")
        original_record = cursor.fetchone()
        
        if not original_record:
            print("❌ 没有找到可测试的记录")
            return False
        
        record_id = original_record[0]
        print(f"📝 测试记录ID: {record_id}")
        print(f"   原始数据: 内容={original_record[4]}, 金额={original_record[5]}, 类别={original_record[3]}")
        
        # 2. 模拟Flutter应用的UPDATE查询
        new_work_content = "测试修改内容"
        new_amount = 999.99
        new_category = "测试类别"
        new_staff_ids = '["1", "2"]'
        
        update_query = '''
            UPDATE records 
            SET work_content = %s, amount = %s, category = %s, staff_ids = %s
            WHERE id = %s
        '''
        
        print(f"🔧 执行UPDATE查询:")
        print(f"   SQL: {update_query}")
        print(f"   参数: work_content={new_work_content}, amount={new_amount}, category={new_category}, staff_ids={new_staff_ids}, id={record_id}")
        
        cursor.execute(update_query, [
            new_work_content,
            new_amount,
            new_category,
            new_staff_ids,
            record_id
        ])
        
        connection.commit()
        print("✅ UPDATE查询执行成功")
        
        # 3. 验证修改是否生效
        cursor.execute("SELECT * FROM records WHERE id = %s", [record_id])
        updated_record = cursor.fetchone()
        
        print(f"📊 验证修改结果:")
        print(f"   修改前: 内容={original_record[4]}, 金额={original_record[5]}, 类别={original_record[3]}, staff_ids={original_record[8]}")
        print(f"   修改后: 内容={updated_record[4]}, 金额={updated_record[5]}, 类别={updated_record[3]}, staff_ids={updated_record[8]}")
        
        # 检查修改是否成功
        if (updated_record[4] == new_work_content and 
            float(updated_record[5]) == new_amount and 
            updated_record[3] == new_category and
            updated_record[8] == new_staff_ids):
            print("✅ 修改账目上传功能正常")
        else:
            print("❌ 修改账目上传功能异常")
            
        # 4. 恢复原始数据
        restore_query = '''
            UPDATE records 
            SET work_content = %s, amount = %s, category = %s, staff_ids = %s
            WHERE id = %s
        '''
        
        cursor.execute(restore_query, [
            original_record[4],
            original_record[5],
            original_record[3],
            original_record[8],
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

def check_update_syntax():
    """检查UPDATE语句的语法"""
    
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
        
        print("\n🔍 检查UPDATE语句语法...")
        
        # 检查表结构
        cursor.execute("DESCRIBE records")
        columns = cursor.fetchall()
        
        print("   表结构:")
        for column in columns:
            print(f"     - {column[0]}: {column[1]}")
        
        # 检查Flutter应用使用的UPDATE语句
        flutter_update = '''
            UPDATE records 
            SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
            WHERE id = ?
        '''
        
        print(f"\n   Flutter应用的UPDATE语句:")
        print(f"   {flutter_update}")
        
        # 验证字段名称
        expected_columns = ['date', 'category', 'work_content', 'amount', 'ledger', 'image_url', 'staff_ids', 'id']
        actual_columns = [col[0] for col in columns]
        
        print(f"\n   字段验证:")
        for col in expected_columns:
            if col in actual_columns:
                print(f"     ✅ {col}: 存在")
            else:
                print(f"     ❌ {col}: 不存在")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"❌ 语法检查失败: {e}")
        return False

if __name__ == "__main__":
    print("🔧 修改账目上传功能测试")
    print("=" * 50)
    
    # 测试UPDATE功能
    if test_update_record():
        # 检查语法
        check_update_syntax()
    
    print("\n✨ 测试完成！")