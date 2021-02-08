#define MB8866_DEBUG 0

#include "Arduino.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "fdc8866.h"
#include "SdFat.h"

// SD_FAT_TYPE = 0 for SdFat/File as defined in SdFatConfig.h,
// 1 for FAT16/FAT32, 2 for exFAT, 3 for FAT16/FAT32 and exFAT.
#define SD_FAT_TYPE 0

// SDCARD_SS_PIN is defined for the built-in SD on some boards.
#ifndef SDCARD_SS_PIN
const uint8_t SD_CS_PIN = SS;
#else  // SDCARD_SS_PIN
// Assume built-in SD is used.
const uint8_t SD_CS_PIN = SDCARD_SS_PIN;
#endif  // SDCARD_SS_PIN

// Try to select the best SD card configuration.
#if HAS_SDIO_CLASS
#define SD_CONFIG SdioConfig(FIFO_SDIO)
#elif ENABLE_DEDICATED_SPI
#define SD_CONFIG SdSpiConfig(SD_CS_PIN, DEDICATED_SPI)
#else  // HAS_SDIO_CLASS
#define SD_CONFIG SdSpiConfig(SD_CS_PIN, SHARED_SPI)
#endif  // HAS_SDIO_CLASS

#if SD_FAT_TYPE == 0
SdFat sd;
File file;
#elif SD_FAT_TYPE == 1
SdFat32 sd;
File32 file;
#elif SD_FAT_TYPE == 2
SdExFat sd;
ExFile file;
#elif SD_FAT_TYPE == 3
SdFs sd;
FsFile file;
#else  // SD_FAT_TYPE
#error Invalid SD_FAT_TYPE
#endif  // SD_FAT_TYPE

//#define DEBUG true
//#define MB8866DEBUG_SERIAL Serial

//define debugging features
#define MB8866DEBUG true
#define MB8866DEBUG_SERIAL if(MB8866DEBUG) Serial




/*---------------------------------------------------------------------------------------------------
// SHARP MZ-80B Disk format
//
// The Sharp MZ-80B basically uses two different disk format:
// 1. 35 Tracks / Double density / 2 sides     Capacity: 350kb  Sector Length: 512kb Block Size: 16 records/2kb
// 2. 40 Tracks / Double density / 2 sides     Capacity: 400kb  Sector Length: 512kb Block Size: 16 records/2kb
//
// 
// MB8866
//
//     : /CS  :  A1  :  A0  :  /RE=0  :  /WE=0  :  Data bus        :
//--------------------------------------------------------------------------------------------------
//     :  1   :  *   :  *   : Deselect: Deselect:  High impedance  :
//     :  0   :  0   :  0   : STR     : CR      :  Enabled         : FDC_STATCOM   fdcstat
//     :  0   :  0   :  1   : TR      : TR      :  Enabled         : FDC_TRACK     fdctrack
//     :  0   :  1   :  0   : SCR     : SCR     :  Enabled         : FDC_SECTOR    fdcsector
//     :  0   :  1   :  1   : DR      : DR      :  Enabled         : FDC_DATA      fdcdata
//
// STR: STATUS REGISTER
// CR: COMMAND REGISTER
// TR: TRACK REGISTER
// SCR: SECTOR REGISTER
// DR: DATA REGISTER
//
// fdcstat    equ $0D8  ; If read = status register, if write = command register MZ-80B address
// fdctrack   equ $0D9  ; track register MZ-80B address
// fdcsector  equ $0DA  ; sector register MZ-80B address
// fdcdata    equ $0DB  ; data register MZ-80B address
// fdcctrl1   equ $0DC  ; control register MZ-80B address - bit0 = drive select (0 = drive 1, 1 = drive 2)
//                                                        - bit1 = drive select (0 = drive 3, 1 = drive 4)
//                                                        - bit2 = select drive (0 = not selected, 1 = selected)
//                                                        - bit3 = not used
//                                                        - bit4 = not used
//                                                        - bit5 = not used
//                                                        - bit6 = not used
//                                                        - bit7 = motor on (1 = enabled, 0 = disabled)
// fdcctrl2   equ $0DD  ; control register MZ-80B address - bit0 = side select (0 = side 1, 1 = side 2)
//
// All data are inverted (negative logic)
// DRQ (Data request) is available as a bit status on the SR register (bit 4)
// This output indicate status of the data request
// On read ops., DRQ=1 shows DR is filled by a byte data so MPU can read the data
// On write ops., DRQ=1 shows DR is empty, FDC is requesting the MPU to write a data byte into DR
// DRQ=0 (reset) by read or write operation completed
// INTRQ bit goes high when Command is completed or stopped
// This bit is reset when next Command is written or STR is read
// /DDEN=0 ==> Double density, /DDEN=1 ==> Single density
//
//--------------------------------------------------------------------------------------------------*/

static File disk;
static uint8_t diskTrackdata[1024];
static unsigned long fdc_cycles;
static int s_byte;  // byte within sector
static bool ReadSectorDone;

int a;

extern unsigned long clock_cycle_count;


uint8_t fdc_intrq() {
  if(fdc.intrq == 1) {
    MB8866DEBUG_SERIAL.printf("FDC MB8866: INTRQ Fired");
  }
  return(fdc.intrq);
}


uint8_t fdc_drq() {
  if ( (fdc.sr & 0x02) == 0x02 ) {
    MB8866DEBUG_SERIAL.printf("FDC MB8866: DRQ Fired");
  }
  return( (fdc.sr & 0x02) == 0x02); //DRQ bit
}


//Check if the SD card is readeable and expect a specific file to be on first boot place (disk 0)
int fdc_init() {
  ReadSectorDone = true;
 
  // Initialize the SD.
  if (!sd.begin(SD_CONFIG)) {
    sd.initErrorHalt(&Serial);
    return(-2);
  }

  disk = sd.open("6610.mzf"); // TO DO: CHOOSE FROM AVAIL IMGs IN SD ROOT DIRECTORY
  if (disk) { 
    MB8866DEBUG_SERIAL.println("Found MZ80B image disk: 6610.mzf");
  } else {
    MB8866DEBUG_SERIAL.println("Error: MZ80B image disk not found!!!");
    return(-1);
  }
  
  return(0); 
}

//init start configuration for all the registers
void fdc_init_registers() {

//initial MB8866 register setup
  fdc.sr = B10000010;              //For type I commands: initial fdc.sr= 10100100  (0x0A4)
                                   //For type II/III commands: initial fdc.sr= 10000010 (0x82) 
  fdc.cr = 0;
  fdc.trk_r = 0;
  fdc.sec_r = 0;
  fdc.data_r = 0;
  fdc.ctrl1_r = B10110100;    //0xB4       //bit2 = select drive (0 = not selected, 1 = selected), bit 7 = motor on
  fdc.ctrl2_r = B0;           //0x00       //bit0 = side select (0 = side 1, 1 = side 2)
  fdc.intrq = 0;
 
}

//run the complete MB8866 emulation cycle
void fdc_run() {

  //if MZ-80B issue a /WR and /IOREQ signal, MZ-80B wants to write on specific registers
  //so here, teensy read data port and assign data to fdc.cr

  //Anding fdc.cr with 11110000 (240)
  switch (fdc.cr & 0xf0) {
    //
    case 0x00:  // Restore
      MB8866DEBUG_SERIAL.print("***** fdc_run(): restore\n");
      fdc.trk_r = 0;  // Track 0
      fdc.sr = 0x04;  // We are emulating TR00 HIGH from the FDC (track at 0), clear BUSY and DRQ INTERRUPT
      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
      fdc.intrq = 1; // Assert INTRQ interrupt at the end of command
      return;
      break;
    
    case 0x10:  // Seek
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Seek\n");
      fdc.trk_r = fdc.data_r;
      fdc.sr = 0; // Clear BUSY and DRQ INTERRUPT
      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
      if (fdc.trk_r == 0) fdc.sr |= 0x04;  // track at 0, emulates TR00 HIGH for Type 1 command
      fdc.intrq = 1; // Assert INTRQ interrupt at the end of command
      return;
      break;

    case 0x20:   //Step
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Step\n");

      return;
      break;

    case 0x40:  // Step In  (corrected from 50...)
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Step In\n");
      fdc.intrq = 1; // Assert INTRQ interrupt at the end of command
      return;
      break;
      
    case 0x60:  // Step Out
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Step Out\n");
      fdc.intrq = 1; // Assert INTRQ interrupt at the end of command
      return;
      break;
      
    case 0x80:  // Read Data
      if (ReadSectorDone) {
//                MB8866DEBUG_SERIAL.print("FDC RUN: Performing Seek @ %d;  ", (1024*fdc.sec_r)+(5632*fdc.trk_r));
//                MB8866DEBUG_SERIAL.print("s_byte = %d\n", s_byte);
                disk.seek((1024*fdc.sec_r)+(5632*fdc.trk_r));
                disk.read(diskTrackdata, 1024);
                }
      a = s_byte;
      if(s_byte > 1024) MB8866DEBUG_SERIAL.print("**************SOMETHING IS WRONG*************"); // remove this after debug
      fdc.data_r = diskTrackdata[a];
      //MB8866DEBUG_SERIAL.printf("*** fdc_run(): s_byte=%04x trk=%d sec=%d disk addr = %04x data=%02x\n",s_byte, fdc.trk_r, fdc.sec_r, a, fdc.data_r);
      fdc.sr |= 0x02;  // Assert IRQ_, Data is ready!
      s_byte++;
      fdc_cycles = clock_cycle_count + 32; // original 32
      
      if (s_byte > (fdc.sec_r == 5 ? 512 : 1024) ) {
                fdc.sr &= 0xfe; // Clear the Busy Bit, we will disregard the last value read anyway, this is needed to keep irq and nmi in sync
                ReadSectorDone = true; // NEXT TIME: This will force reading a new sector of 1024 bytes from the SD card
//                MB8866DEBUG_SERIAL.print("SDFDC: Done reading sector %x\n", fdc.sec_r);
                fdc.intrq = 1; // NMI_ Interrupt at the end of READ SECTOR command
                }
                else 
                  ReadSectorDone = false;
      return;
      break;

    case 0xA0:  // Write Data 
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Write data\n");

      return;
      break;

    case 0xC0:  // Read Address 
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Read address\n");

      return;
      break;

    case 0xE0:  // Read Track 
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Read track\n");

      return;
      break;

    case 0xF0:  // Write Track 
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Write track\n");

      return;
      break;

    case 0xD0:  // Force Interrupt
      MB8866DEBUG_SERIAL.print("***** fdc_run(): Force interrupt\n");

      return;
      break;  
      
    default: // Others
//      MB8866DEBUG_SERIAL.print("***** FDC EMULATION RUN: NOT SUPPORTED(%02x)\n", fdc.cr);
      fdc.sr = 0;
      return;
      break;
  }
    // Should we ever get here?
  fdc.sr &= 0xfe; // stop, clear BUSY bit
//    MB8866DEBUG_SERIAL.print("***** FDC EMULATION RUN: <fdc.sr &= 0xfe;  // stop> where fdc.sr =%02x ", fdc.sr);
}

uint8_t fdc_rreg(uint8_t reg) {
  
  // handle reads from FDC registers
  uint8_t val;

  switch (reg & 0x03) {
    case FDC_SR:
            val = fdc.sr;
            fdc.intrq = 0; //INTRQ is de-asserted (NMI_ goes HIGH) after reading the STATUS REGISTER
//#if MB8866_DEBUG
            MB8866DEBUG_SERIAL.print("FDC_RREG FDC: SR ");
      //      MB8866DEBUG_SERIAL.print(" val => %02x (FDC)\n",val);
//#endif
            break;
    case FDC_TRACK:
            val = fdc.trk_r;
//#if MB8866_DEBUG
            MB8866DEBUG_SERIAL.print("FDC_RREG FDC_TRACK: ");
//            MB8866DEBUG_SERIAL.print(" val => %02x (FDC)\n",val);
//#endif
            break;
    case FDC_SECTOR: 
            val =  fdc.sec_r;
//#if MB8866_DEBUG
            MB8866DEBUG_SERIAL.print("FDC_RREG FDC_SECTOR: ");
      //      MB8866DEBUG_SERIAL.print(" val => %02x (FDC)\n",val);
//#endif
            break;
    case FDC_DATA:
           // MB8866DEBUG_SERIAL.printf("FDC_RREG DATA, I clear the IRQ bit. DATA "); Serial.printf(" val => %02x (FDC)\n",val);
            fdc.sr &= 0xfd; // mask is 1111_1101, we are clearing the DRQ bit (IRQ_ goes HIGH) as Data is being read
            val =  fdc.data_r;
            break;
      default: 
//            MB8866DEBUG_SERIAL.print("*** FDC READING REGISTER EMULATION reg %02x: CURRENTLY NOT SUPPORTED\n", reg);
            break;
  }
  
  return(val);
}

void fdc_wreg(uint8_t reg, uint8_t val) {
  
  // handle writes to FDC registers
  int cmd = (val & 0xf0)>>4;

  //Serial.printf("Entering: FDC_WREG\n");
  //Serial.printf("FDC_WREG reg => %02x; val =>  %02x\n", reg, val);
  //Serial.printf("FDC_WREG cmd => %02x\n", cmd);
  //Serial.printf("FDC_WREG reg & 0x03 = > %02x\n", reg & 0x03);

  switch (reg & 0x03) {
    case FDC_CR: // 0
            fdc.intrq = 0; //INTRQ is de-asserted (NMI_ goes HIGH) after loading the Command Register with new command
#if MB8866_DEBUG
            DEBUG_SERIAL.print("FDC_WREG COMMAND fdc.cr = %02x\n", val);
#endif
      if ((val & 0xf0) == 0xd0) { // mask is 1111_0000, comparig with 1101_0000 force interrupt
#if MB8866_DEBUG
              DEBUG_SERIAL.print("FDC_WREG cmd %02x: force interrupt\n", val);
#endif
              fdc.sr &= 0xfe; // mask is 1111_1110,  we are clearing the busy bit
              return;
              }
#if MB8866_DEBUG
            DEBUG_SERIAL.print("FDC_WREG FDRC fdc.sr & 0x01 shows %s BUSY\n", fdc.sr & 0x01 ? "" : "NOT" );
#endif
      if (fdc.sr & 0x01) return; // Just return if BUSY
#if MB8866_DEBUG
            DEBUG_SERIAL.print("FDC_WREG FDRC: cmd %02x val = %02x\n", cmd, val);
#endif
      fdc.cr = val;
      switch(cmd) {
             case 0x0: // Restore
#if MB8866_DEBUG
                      DEBUG_SERIAL.print("FDC_WREG cmd %02x: restore\n",  val);
#endif
                      fdc_cycles = clock_cycle_count + 1000; //1000000;   // remove (or minimize) tbis
                      fdc.sr = 0x01; // busy
                      break;
             case 0x1: // Seek
#if MB8866_DEBUG
                      DEBUG_SERIAL.print("FDC_WREG cmd %02x: seek to %d\n", val, fdc.data_r);
#endif
                      fdc_cycles = clock_cycle_count + 1000; //1000000;   // remove (or minimize) tbis
                      fdc.sr = 0x01;  // busy
                      break;
             case 0x5: // Step In
#if MB8866_DEBUG
                      DEBUG_SERIAL.print("FDC_WREG cmd %02x: Step in %d\n", val, fdc.trk_r++);
#endif
                      fdc_cycles = clock_cycle_count + 100; //100000;    // remove (or minimize) tbis
                      fdc.trk_r++;
                      fdc.sr = 0x01;  // busy
                      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
                      break;
             case 0x6: // Step Out
#if MB8866_DEBUG
                      DEBUG_SERIAL.print("FDC_WREG cmd %02x: Step out (w/o Update) %d\n", val, fdc.trk_r--);
#endif
                      fdc_cycles = clock_cycle_count + 100; //100000;    // remove (or minimize) tbis
                      fdc.trk_r--;
                      fdc.sr = 0x01;  // busy
                      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
                      break;
             case 0x7:
//                      DEBUG_SERIAL.print("*** FDC WRITING COMMAND: Step Out (w Update (%02x) CURRENTLY NOT SUPPORTED (val = %02x)\n", cmd, val);
                      break;
             case 0x8: // Read Single Sector
#if MB8866_DEBUG
                      Serial.print("FDC_WREG cmd %02x: read sector\n", val);
#endif
                      fdc_cycles = clock_cycle_count + 10; //1000;    // remove (or minimize) tbis
                      s_byte = 0;
                      fdc.sr = 0x01; // busy
                      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
                      break;
             case 0xa: // Write Single Sector
//                      DEBUG_SERIAL.print("*** FDC WRITING COMMAND: Write Single Sector (%02x) CURRENTLY NOT SUPPORTED (val = %02x)\n", cmd, val);
                      break;
             case 0xb: // Write Multiple Sectors
//                      DEBUG_SERIAL.print("*** FDC WRITING COMMAND: Write Multiple Sectors (%02x) CURRENTLY NOT SUPPORTED (val = %02x)\n", cmd, val);
                      break;
             case 0xf: // Write Track
//                      DEBUG_SERIAL.print("*** FDC WRITING COMMAND: Write Track (%02x) CURRENTLY NOT SUPPORTED (val = %02x)\n", cmd, val);
                      break;
              default: //0f
//                      DEBUG_SERIAL.print("*** FDC WRITING REGISTER EMULATION: COMMAND cmd %02x: CURRENTLY NOT SUPPORTED (val = %02x)\n", cmd, val);
                      fdc.sr = 0;
                      fdc_cycles = 0;
                      break;
              }
      break;
    case FDC_TRACK:
#if MB8866_DEBUG
      DEBUG_SERIAL.print("FDC_WREG *TRACK* = %d\n",  val);
#endif
      fdc.trk_r = val; 
      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
      break;
    case FDC_SECTOR:
#if MB8866_DEBUG
      DEBUG_SERIAL.print("FDC_WREG *SECTOR* = %d\n", val);
#endif
      fdc.sec_r = val;
      ReadSectorDone = true; // This will force reading a new sector of 1024 bytes from the SD card
      break;
    case FDC_DATA:
#if MB8866_DEBUG
      DEBUG_SERIAL.print("FDC_WREG *DATA* = %d\n", val);
#endif
      fdc.data_r = val;
      break;
    default:
//      DEBUG_SERIAL.print("*** FDC WRITING REGISTER EMULATION reg %02x: CURRENTLY NOT SUPPORTED\n", reg);
      fdc.sr = 0;
      fdc_cycles = 0;
      break;
  }
}
