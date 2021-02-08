#include <avr/io.h>
#include <avr/interrupt.h>

#include "fdc8866.h"

//Define pin assignment for Teensy 4.1 ports

//MZ80B address decoding
#define MZ_A0 14 //
#define MZ_A1 15 //
#define MZ_A2 16 //
#define MZ_A3 17 //
#define MZ_A4 18 //
#define MZ_A5 19 //
#define MZ_A6 20 //
#define MZ_A7 21 //

//MZ80B data bus
#define MZ_D0 31 //     
#define MZ_D1 30 //     
#define MZ_D2 29 //     
#define MZ_D3 28 //     
#define MZ_D4 27 //     
#define MZ_D5 26 //     
#define MZ_D6 25 //     
#define MZ_D7 24 //     

//MZ80B control signals

#define MZ_RESET 32
#define MZ_IPLRESET 8
#define MZ_IOREQ 7
#define MZ_RD 3
#define MZ_WR 2
#define MZ_EXWAIT 22
#define MZ_EXRESET 23
#define T_DIRDATA 5
#define T_IODATA 6
 
//MZ80B MB8866 Floppy Controller registers address


//define debugging features
#define DEBUG true
#define DEBUG_SERIAL if(DEBUG) Serial


volatile byte baseAddress = B0;


struct MZADDRESS {

  byte A0_Bit: 1;
  byte A1_Bit: 1;
  byte A2_Bit: 1;
  byte A3_Bit: 1;
  byte A4_Bit: 1;
  byte A5_Bit: 1;
  byte A6_Bit: 1;
  byte A7_Bit: 1;
};

union ADDRESS
{
  MZADDRESS mzAddress;
  byte value;
};

ADDRESS t_address;

struct MZDATA {

  byte D0_Bit: 1;
  byte D1_Bit: 1;
  byte D2_Bit: 1;
  byte D3_Bit: 1;
  byte D4_Bit: 1;
  byte D5_Bit: 1;
  byte D6_Bit: 1;
  byte D7_Bit: 1;
};

union DATA
{
  MZDATA mzData;
  byte value;
};

DATA t_data;


volatile boolean checkit = false;


void setup() {

  digitalWrite(MZ_EXWAIT, LOW); //Force MZ80B to wait until Teensy has finished his setup
  
  
  
  digitalWrite(T_IODATA, HIGH);    //Disable data bus
  
  init_ports();
  fdc_init_registers();
  fdc_init();
  
  
  digitalWrite(MZ_IPLRESET,HIGH);
  digitalWrite(MZ_EXRESET, HIGH);
  digitalWrite(T_DIRDATA, HIGH);   //Set Data Bus MZ-80B in write mode (flow from A to B)
  digitalWrite(T_IODATA, LOW);    //Enable data bus

  
  digitalWrite(MZ_EXWAIT, HIGH);    //Release MZ80B wait state
  
  
  
  
  attachInterrupt(digitalPinToInterrupt(MZ_IOREQ), check_ioreq, FALLING);
  NVIC_SET_PRIORITY(IRQ_GPIO6789, 0); //IRQ_GPT2 also ok

  //NVIC_ENABLE_IRQ((IRQ_NUMBER_t) 14); running?

  //NVIC_ENABLE_IRQ(IRQ_GPT1);
  //NVIC_DISABLE_IRQ(IRQ_GPT1);
  //checkit = NVIC_IS_ENABLED(IRQ_GPT1);

  //Memory barrier to ensure Interrupts are actually disabled!
  //asm volatile("dsb");

  if (DEBUG) {  
    DEBUG_SERIAL.begin(115200);
    DEBUG_SERIAL.print("START Serial Debugging\n");
  } else {
    DEBUG_SERIAL.print("END Serial Debugging..\n");
    DEBUG_SERIAL.end();
    disable_ports();
  }

  DEBUG_SERIAL.print("IPL RESET...\n");
  delay(1000);
  ipl_reset();
  
}

void sharp_reset() {
  DEBUG_SERIAL.print("MZ80B RESET...\n");
}

void ipl_reset() {
  
  digitalWrite(MZ_IPLRESET,LOW);
  delay(10);
  digitalWrite(MZ_IPLRESET,HIGH);
  
}

void std_reset() {
  
  digitalWrite(MZ_EXRESET,LOW);
  delay(10);
  digitalWrite(MZ_EXRESET,HIGH);
}

void check_ioreq() {

  //Get Address lines and compare with disk address space

  //Set Data Bus MZ-80B in write mode (flow from A to B)
  //digitalWrite(T_DIRDATA, HIGH);   ////Set Data Bus MZ-80B in write mode (flow from A to B)
  //digitalWrite(T_IODATA, LOW);    //Enable data bus

  t_address.mzAddress.A0_Bit = digitalRead(MZ_A0);
  t_address.mzAddress.A1_Bit = digitalRead(MZ_A1);
  t_address.mzAddress.A2_Bit = digitalRead(MZ_A2);
  t_address.mzAddress.A3_Bit = digitalRead(MZ_A3);
  t_address.mzAddress.A4_Bit = digitalRead(MZ_A4);
  t_address.mzAddress.A5_Bit = digitalRead(MZ_A5);
  t_address.mzAddress.A6_Bit = digitalRead(MZ_A6);
  t_address.mzAddress.A7_Bit = digitalRead(MZ_A7);

  baseAddress = t_address.value & B11111000;

  if (baseAddress == 0x0D8) { 

    fdc_run();

/*


    
 
    if (digitalRead(MZ_RD) == LOW) {

      //MZ-80B try to read an address from the bus, teensy is in write mode...

      digitalWrite(T_DIRDATA, LOW);   //Set Data Bus in MZ_80B read mode (flow from B to A)
      digitalWrite(T_IODATA, LOW);    //Enable data bus

      t_data.value = 0x0A5;  //Actually set to A5, but has to reflect real data value after ....

      

      switch(t_address.value) {

        case (0x0D8):   //t_data.value = 0xA0;
                        DEBUG_SERIAL.print("Read Status register: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        

                        //return;
                        break;
        
        case (0x0D9):   DEBUG_SERIAL.print("Read Track register: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        t_data.value = fdc.trk_r;
                        //return;
                        break;                

        case (0x0DC):   DEBUG_SERIAL.print("Read Control register 1: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        t_data.value = fdc.ctrl1_r;
                        //return;
                        break;
 
      }

      digitalWrite(MZ_D0,t_data.mzData.D0_Bit);
      digitalWrite(MZ_D1,t_data.mzData.D1_Bit);
      digitalWrite(MZ_D2,t_data.mzData.D2_Bit);
      digitalWrite(MZ_D3,t_data.mzData.D3_Bit);
      digitalWrite(MZ_D4,t_data.mzData.D4_Bit);
      digitalWrite(MZ_D5,t_data.mzData.D5_Bit);
      digitalWrite(MZ_D6,t_data.mzData.D6_Bit);
      digitalWrite(MZ_D7,t_data.mzData.D7_Bit);

//      DEBUG_SERIAL.print("MZ-80B READ Address: ");
//      DEBUG_SERIAL.print(t_address.value, HEX);
//      DEBUG_SERIAL.print(" -- READ Data: ");
//      DEBUG_SERIAL.print(t_data.value, HEX);
//      DEBUG_SERIAL.print("\n");

      digitalWrite(T_DIRDATA, HIGH);   ////Set Data Bus MZ-80B in write mode (flow from A to B)
      digitalWrite(T_IODATA, LOW);    //Enable data bus

      //fdc_rreg(t_address.value);
      //mzRead(t_address.value);
 
    }

    if (digitalRead(MZ_WR) == LOW) {

      //MZ-80B try to write an address from the bus, teensy is in read mode...

      digitalWrite(T_DIRDATA, HIGH);   //Set Data Bus MZ-80B in write mode (flow from A to B)
      digitalWrite(T_IODATA, LOW);    //Enable data bus

      

      t_data.mzData.D0_Bit = digitalRead(MZ_D0);
      t_data.mzData.D1_Bit = digitalRead(MZ_D1);
      t_data.mzData.D2_Bit = digitalRead(MZ_D2);
      t_data.mzData.D3_Bit = digitalRead(MZ_D3);
      t_data.mzData.D4_Bit = digitalRead(MZ_D4);
      t_data.mzData.D5_Bit = digitalRead(MZ_D5);
      t_data.mzData.D6_Bit = digitalRead(MZ_D6);
      t_data.mzData.D7_Bit = digitalRead(MZ_D7);

      digitalWrite(T_DIRDATA, HIGH);   ////Set Data Bus MZ-80B in write mode (flow from A to B)
      digitalWrite(T_IODATA, LOW);    //Enable data bus

      switch(t_address.value) {

        case (0x0D8):   DEBUG_SERIAL.print("Write Command register: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        fdc.sr = t_data.value;

                        //return;
                        break;

        case (0x0D9):   DEBUG_SERIAL.print("Write Track register: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        fdc.trk_r = t_data.value;
                        
                        //return;
                        break;                
                        

        case (0x0DC):   DEBUG_SERIAL.print("Write Control register 1: ");
                        DEBUG_SERIAL.print(t_data.value, HEX);
                        DEBUG_SERIAL.print("\n");

                        fdc.ctrl1_r = t_data.value;
                        
                        //return;
                        break;




        
      }
      
      //DEBUG_SERIAL.print("MZ-80B WRITE Address: ");
      //DEBUG_SERIAL.print(t_address.value, HEX);
      //DEBUG_SERIAL.print(" -- WRITE Data: ");
      //DEBUG_SERIAL.print(t_data.value, HEX);
      //DEBUG_SERIAL.print("\n");

      //fdc_wreg(t_address.value,t_data.value);
     
    }
 
*/
  }
}


void loop() {
 
}


void init_ports() {

  //Set MZ-80B Address Lines as input for Teensy
  pinMode(MZ_A0, INPUT);
  pinMode(MZ_A1, INPUT);
  pinMode(MZ_A2, INPUT);
  pinMode(MZ_A3, INPUT);
  pinMode(MZ_A4, INPUT);
  pinMode(MZ_A5, INPUT);
  pinMode(MZ_A6, INPUT);
  pinMode(MZ_A7, INPUT);

  //Set MZ-80B Data Lines as input for Teensy
  pinMode(MZ_D0, INPUT);
  pinMode(MZ_D1, INPUT);
  pinMode(MZ_D2, INPUT);
  pinMode(MZ_D3, INPUT);
  pinMode(MZ_D4, INPUT);
  pinMode(MZ_D5, INPUT);
  pinMode(MZ_D6, INPUT);
  pinMode(MZ_D7, INPUT);

  //Set MZ-80B Signal Lines as input for teensy, except /EXWAIT signal as output
  
  pinMode(MZ_IOREQ, INPUT);
  pinMode(MZ_RD, INPUT);
  pinMode(MZ_WR, INPUT);
  pinMode(MZ_EXRESET, OUTPUT);
  pinMode(MZ_IPLRESET,OUTPUT);
  pinMode(MZ_EXWAIT, OUTPUT);
  pinMode(MZ_RESET,INPUT);

  //Set bus arbitration signals as output for teensy
  pinMode(T_DIRDATA, OUTPUT);
  pinMode(T_IODATA, OUTPUT);

}

void disable_ports() {

  digitalWrite(T_DIRDATA, LOW);   ////Set Data Bus MZ-80B in write mode (flow from A to B)
  digitalWrite(T_IODATA, HIGH);    //Disable data bus
  ipl_reset();
}





void mzRead(uint8_t mzaddress) {


  switch (mzaddress) {

    case 0x0D8:   DEBUG_SERIAL.print("Read status register");
                  break;

    case 0x0D9:   t_data.value = fdc.trk_r;  //0x00A5
                  DEBUG_SERIAL.print("Read track register");
                  break;              

    case 0x0DA:   DEBUG_SERIAL.print("Read sector register");
                  break;  

    case 0x0DB:   DEBUG_SERIAL.print("Read data register");
                  break;               

    case 0x0DC:   DEBUG_SERIAL.print("Read control register 1");
                  t_data.value = 0x84;
                  break; 

    case 0x0DD:   DEBUG_SERIAL.print("Read control register 2");
                  t_data.value = 0x00;
                  break; 
  }
}

void mzWrite(uint8_t mzaddress) {

switch (mzaddress) {

    case 0x0D8:   DEBUG_SERIAL.print("Write status register");
                  break;

    case 0x0D9:   t_data.mzData.D0_Bit = digitalRead(MZ_D0);
                  t_data.mzData.D1_Bit = digitalRead(MZ_D1);
                  t_data.mzData.D2_Bit = digitalRead(MZ_D2);
                  t_data.mzData.D3_Bit = digitalRead(MZ_D3);
                  t_data.mzData.D4_Bit = digitalRead(MZ_D4);
                  t_data.mzData.D5_Bit = digitalRead(MZ_D5);
                  t_data.mzData.D6_Bit = digitalRead(MZ_D6);
                  t_data.mzData.D7_Bit = digitalRead(MZ_D7);
    
                  fdc.trk_r = t_data.value; //0x00A5
                  DEBUG_SERIAL.print("Write track register");
    
                  
                  break;              

    case 0x0DA:   DEBUG_SERIAL.print("Write sector register");
                  break;  

    case 0x0DB:   DEBUG_SERIAL.print("Write data register");
                  break;               

    case 0x0DC:   DEBUG_SERIAL.print("Write control register 1");
                  fdc.ctrl1_r = 0x84;
                  break; 

    case 0x0DD:   DEBUG_SERIAL.print("Write control register 2");
                  fdc.ctrl2_r = 0x00;
                  break; 
  }
}
