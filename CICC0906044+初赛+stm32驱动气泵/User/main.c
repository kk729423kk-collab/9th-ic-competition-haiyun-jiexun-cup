#include "stm32f10x.h"                  // Device header
#include "Delay.h"
#include "OLED.h"
#include "Serial.h"
#include "LED.h"
#include "string.h"

void gpio_init()
{
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA,ENABLE);
	GPIO_InitTypeDef gpio_type;
	gpio_type.GPIO_Mode=GPIO_Mode_IPD;
	gpio_type.GPIO_Pin=GPIO_Pin_0;
	gpio_type.GPIO_Speed=GPIO_Speed_50MHz;
	GPIO_Init(GPIOA,&gpio_type);
}
int main(void)
{
	/*模块初始化*/
	OLED_Init();		//OLED初始化
	LED_Init();			//LED初始化
	Serial_Init();		//串口初始化
	gpio_init();
	/*显示静态字符串*/
	OLED_ShowString(1, 4, "pump_ctrl");
	
	char flag=0;
	while (1)
	{
		
		OLED_ShowNum(2,1,flag,1);
		if(GPIO_ReadInputDataBit(GPIOA,GPIO_Pin_0)==1&&flag==0)
		{
			Serial_Printf("#255P2500T0000!");
			flag=1;
		}
		else if(GPIO_ReadInputDataBit(GPIOA,GPIO_Pin_0)==0&&flag==1)
		{
			Serial_Printf("#255P1500T0000!");

			flag=0;
		}
		//Serial_Printf("#255P2500T0000!");
	}
}
