#include <stdio.h>
typedef struct { long tag; long u; } HexaVal;
extern HexaVal hexa_str(const char*); extern HexaVal hexa_int(long);
extern HexaVal rt_str_pad_left(HexaVal,HexaVal,HexaVal);
extern HexaVal rt_str_pad_right(HexaVal,HexaVal,HexaVal);
extern HexaVal rt_str_repeat(HexaVal,HexaVal);
extern HexaVal rt_str_center(HexaVal,HexaVal,HexaVal);
extern HexaVal rt_str_to_upper(HexaVal); extern HexaVal rt_str_to_lower(HexaVal);
extern HexaVal rt_str_trim(HexaVal); extern HexaVal rt_str_trim_start(HexaVal); extern HexaVal rt_str_trim_end(HexaVal);
static const char* S(HexaVal v){ return v.u?(const char*)v.u:"(null)"; }
int main(void){
  printf("padL=[%s] exp[007]\n",  S(rt_str_pad_left(hexa_str("7"),hexa_int(3),hexa_str("0"))));
  printf("padR=[%s] exp[700]\n",  S(rt_str_pad_right(hexa_str("7"),hexa_int(3),hexa_str("0"))));
  printf("rep =[%s] exp[ababab]\n", S(rt_str_repeat(hexa_str("ab"),hexa_int(3))));
  printf("ctr =[%s] exp[--hi--]\n", S(rt_str_center(hexa_str("hi"),hexa_int(6),hexa_str("-"))));
  printf("upr =[%s] exp[HELLO, WORLD!]\n", S(rt_str_to_upper(hexa_str("Hello, World!"))));
  printf("lwr =[%s] exp[hello, world!]\n", S(rt_str_to_lower(hexa_str("Hello, World!"))));
  printf("trm =[%s] exp[hi]\n", S(rt_str_trim(hexa_str("  hi  "))));
  printf("trS =[%s] exp[hi  ]\n", S(rt_str_trim_start(hexa_str("  hi  "))));
  printf("trE =[%s] exp[  hi]\n", S(rt_str_trim_end(hexa_str("  hi  "))));
  return 0;
}
