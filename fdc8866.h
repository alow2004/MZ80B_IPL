
#ifndef __FDC_H
#define __FDC_H

// registers
#define FDC_SR 0
#define FDC_CR 0
#define FDC_TRACK 1
#define FDC_SECTOR 2
#define FDC_DATA 3



#include <stdint.h>

int fdc_init();
void fdc_init_registers();
void fdc_run();
uint8_t fdc_rreg(uint8_t reg);
void fdc_wreg(uint8_t reg, uint8_t val);
uint8_t fdc_intrq();
uint8_t fdc_drq();

struct {
  uint8_t sr;       // STATUS REGISTER
  uint8_t cr;       // COMMAND REGISTER
  uint8_t trk_r;    // TRACK REGISTER
  uint8_t sec_r;    // SECTOR REGISTER
  uint8_t data_r;   // DATA REGISTER: holds the data during Read and Write operations
  uint8_t ctrl1_r;  // CONTROL BYTE 0
  uint8_t ctrl2_r;  // CONTROL BYTE 1
  uint8_t intrq;   // Interrupt Request
  
} fdc;

#endif
