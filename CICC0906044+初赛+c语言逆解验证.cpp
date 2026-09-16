#include <stdio.h>
#include <math.h>
#include <stdint.h>

// 定义PI值和角度弧度转换
#define PI 3.14159265358979323846
#define RAD_TO_DEG(rad) ((rad) * 180.0 / PI)


uint16_t angle_to_12bit(double angle) {
    // 直接去掉小数部分（截断）并扩大10倍
    int32_t scaled = ((int32_t)angle)*10;
    
    // 处理12位补码
    if (scaled < 0) {
        scaled = (1 << 12) + scaled;  // 负数转补码
    }
    return scaled & 0xFFF;  // 确保12位
}

// 逆运动学求解函数
void inverse_kinematics(double x, double y, double z, 
                        double L0, double L1, double L2, double L3,
                        double *j0, double *j1, double *j2, double *j3) {
    // 计算中间变量
    double L4 = sqrt(x * x + y * y);
    double L5 = sqrt((L3 + z - L0) * (L3 + z - L0) + L4 * L4);
    
    // 计算余弦值
    double cos_theta1 = (L1 * L1 + L5 * L5 - L2 * L2) / (2 * L1 * L5);
    double cos_theta3 = (L1 * L1 + L2 * L2 - L5 * L5) / (2 * L1 * L2);
    
    // 计算角度theta1, theta2, theta3
    double theta1 = acos(cos_theta1);
    double theta2 = acos(L4 / L5);
    double theta3 = acos(cos_theta3);
    
    // 计算关节角度
    *j0 = acos(x / L4);
    *j1 = PI/2 - theta1 - theta2;
    *j2 = PI - theta3;
    *j3 = theta1 + theta2 + theta3 - PI/2;
    
    // 转换为角度   4 -3
//    		//  
//    *j0 = RAD_TO_DEG(*j0)+2;
//    *j1 = RAD_TO_DEG(*j1)-3;
//    *j2 = RAD_TO_DEG(*j2)-5; //
//    *j3 = RAD_TO_DEG(*j3);  //
    
   *j0 = RAD_TO_DEG(*j0);
    *j1 = RAD_TO_DEG(*j1);// 5  2
    *j2 = RAD_TO_DEG(*j2)-3; //
    *j3 = RAD_TO_DEG(*j3);  //
    
    // 处理j0的方向（根据y的符号）
    if (y < 0) {
        *j0 = -*j0+2;
    }
}
int main() {
    // 机械臂参数（单位：cm）
    double L0 = 8.6;   // 底座高度
    double L1 = 15.5;  // 大臂长度
    double L2 = 14.3;  // 小臂长度
    double L3 = 14;    // 末端长度
    
    // 目标位置（单位：cm）
    double x =10.2;
    double y =-24.5;
    double z = 4; //00 00 00 00
    //42 35 2F 4E  
    // 3E 25 4C 41
    
    // 计算结果
    double j0, j1, j2, j3;
    inverse_kinematics(x, y, z, L0, L1, L2, L3, &j0, &j1, &j2, &j3);
    //00 00 00 00 
    // 打印原始角度值
    printf("原始角度值:\n");
    printf("j0 = %7.2f°\n", j0);
    printf("j1 = %7.2f°\n", j1);
    printf("j2 = %7.2f°\n", j2);
    printf("j3 = %7.2f°\n", j3);
    
    // 计算四舍五入后的整数值（扩大10倍）
    int32_t j0_scaled = ((int32_t)round(j0 ))*10;
    int32_t j1_scaled = ((int32_t)round(j1 ))*10;
    int32_t j2_scaled = ((int32_t)round(j2 ))*10;
    int32_t j3_scaled = ((int32_t)round(j3 ))*10;
    
    // 转换为12位补码
    uint16_t j0_hex = angle_to_12bit(j0);
    uint16_t j1_hex = angle_to_12bit(j1);
    uint16_t j2_hex = angle_to_12bit(j2);
    uint16_t j3_hex = angle_to_12bit(j3);
// 打印原始角度值（8位宽=2个十六进制字符）
printf("\n原始角度值（8位宽十六进制）:\n");
printf(" %02X", (char)(int)j0);
printf(" %02X", (char)(int)j1);
printf(" %02X", (char)(int)j2);
printf(" %02X\n", (char)(int)j3);
    
 
    
    // 拼接为48位数（12个十六进制字符）
    printf("\n拼接后的48位数:\n");
    printf("完整格式: 0x%03X%03X%03X%03X\n", j0_hex, j1_hex, j2_hex, j3_hex);
    printf("紧凑格式: %03X%03X%03X%03X\n", j0_hex, j1_hex, j2_hex, j3_hex);
    
    return 0;
}
