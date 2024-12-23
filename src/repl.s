;;; repl.s
;   A simple REPL - read execute print loop
;   Notes:
;    - Following the vbcc ABI: d0, d1, a0, and a1 are scratch registers.
;    - This embeds the PGX header requirements directly in source.  

;;; System calls
SYSC_EXIT = $00
SYSC_WRITEB = $14
SYSC_READB = $11
SYSC_WRITE = $13
SYSC_READL = $12

    org $010000

;;; PGX header
    dc.b 'PGX',$02
    dc.l start

;;; SIMPLE REPL
start:
    lea intro,a0
    jsr puts

repl:
    lea prompt,a0
    jsr puts

    ; get user input
    lea buffer,a0
    move.l #buffer_end-buffer,d0 ; size of buffer
    jsr gets
    move.l d0,d3 ; save number of bytes received

    ; print line break after input
    jsr putcr

    ; empty line exits
    cmp.l #0,d3
    beq done

    ; check match
    lea buffer,a0
    jsr match_cmd
    move.l d0,d3
    cmp.l #-1,d3 ; handle error if no command found
    beq .error

    ; look up command impl and call
    lsl.l #2,d3 ; d3 = d3 * 4 - each entry is a 32-bit pointer
    ; bounds check offset
    cmp.l #command_impls_end-command_impls,d3
    blt .bounds_ok
    ; bounds check failure, print message and continue
    lea internal_error,a0
    jsr puts
    bra repl
.bounds_ok:
    lea command_impls,a0
    move.l (0,a0,d3),a3 ; a3 <- command_impls + offset + 0
    ; call address held in a3
    jsr (a3)
    bra repl

.error:
    ; unrecognized command
    lea error,a0
    jsr puts
    lea buffer,a0
    jsr puts
    jsr putcr
    bra repl

block_impl:
    move.l #command_impls,d0
    jsr puthexl
    jsr putcr
    rts

hello_impl:
    move.l #buffer,d0
    jsr puthexl
    jsr putcr
    rts
    
done:
quit_impl:
    ; print goodbye
    lea goodbye,a0
    jsr puts

    move.l #SYSC_EXIT,d0
    clr.l d1                        ; exit code = 0
    trap #15

;;; match_cmd - given input buffer match a command in the command table
;;; %a0 - (IN) address of input buffer (input_ptr)
;;; %d0 - (OUT) matched command, -1 == no match (return)
;   a1 - temp input pointer (cur_input_ptr)
;   a2 - temp command list pointer (cmd_list_ptr)
;   d7 - temp current command index (cmd_idx)
;   d0 - temp byte from input buffer (inpc)
;   d1 - temp byte from command buffer (cmdc)
;   TODO: add input %a1 which is a pointer to the string array, make this generic
match_cmd:
    movem.l d2-d7/a2-a6,-(a7)
    clr.l d7 ; int cmd_idx = 0
    move.l #commands,a2 ; char *cmd_list_ptr = &commands
.next_cmd:
    ; if (*cmd_list_ptr == 0) return -1 // no match
    cmp.b #0,(a2)
    beq .no_matches
    move.l a0,a1 ; cur_input_ptr = input_ptr
.match_loop:
    move.b (a1)+,d0 ; inpc = *cur_input_ptr++
    move.b (a2)+,d1 ; cmdc = *cmd_list_ptr++
    cmp.b d0,d1 ; if (inpc == cmdc)
    bne .no_match
    cmp.b #0,d0 ; if (inpc == 0)
    beq .matched ; ... return cmd_idx
    bra .match_loop ; else continue
.no_match: ; } else {
    add.l #1,d7 ; cmd_idx++
.skip:
    cmp.b #0,d1 ; while (cmdc != 0)
    beq .next_cmd ; (break)
    move.b (a2)+,d1 ; cmdc = *cmd_listptr++
    bra .skip
.no_matches:
    move.l #-1,d7
.matched:
    move.l d7,d0
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; putcr - write carriage return to console
putcr:
    move.b #10,d0
    ; notice this falls through to putc
;;; putc - writes a byte to console
;;; %d0 - (IN) byte
putc:
    movem.l d2-d7/a2-a6,-(a7)
    move.b d0,d2
    move.l #SYSC_WRITEB,d0
    clr.l d1
    trap #15
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; puts - writes a null-terminated string to console
;;; %a0 - (IN) pointer to string
puts:
    movem.l d2-d7/a2-a6,-(a7) ; preserve non-scratch
    move.l a0,a3 ; a0 is scratch, move to perm a3
    cmp.l #0,a3
    beq .done ; if a0/a3 are null, exit early
.loop:
    move.b (a3)+,d2
    cmp.b #0,d2
    beq .done ; done if null byte
    ; sys call write byte
    move.l #SYSC_WRITEB,d0 ; sys_call_writeb
    clr.l d1 ; channel 0 - console
    trap #15
    bra .loop
.done:
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; gets - receives input from console until newline or eob - stores in a0
;;; %a0 - (IN) pointer to buffer
;;; %d0.w - (IN) length of buffer
;;; (%a0) - (OUT) received bytes, null terminated.
;;; %d0.w - (OUT) number of bytes received
gets:
    movem.l d2-d7/a2-a6,-(a7)
    move.l d0,d3
    sub.l #1,d3 ; reduce buffer size by 1 for null terminator
    move.l a0,a3 ; preserve input a0 for terminating buffer later
    move.l #SYSC_READL,d0
    clr.l d1 ; console
    move.l a3,d2
    trap #15
    ; null terminate input in buffer
    move.b #0,(0,a3,d0)
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; puthexl - display a 32-bit value in hex
;;; %d0 - (IN) value to display in hex
puthexl:
    movem.l d2-d7/a2-a6,-(a7)
    move.l d0,d2
    lsr.l #8,d0
    lsr.l #8,d0
    jsr puthexw
    move.l d2,d0
    jsr puthexw
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; puthexw - display a 16-bit value in hex
;;; %d0 - (IN) value to display in hex
puthexw:
    movem.l d2-d7/a2-a6,-(a7)
    move.l d0,d2
    lsr.l #8,d0
    jsr puthexb
    move.l d2,d0
    jsr puthexb
    movem.l (a7)+,d2-d7/a2-a6
    rts

;;; puthexb - display a single byte value in hex
;;; %d0 - (IN) value to display in hex
puthexb:
    movem.l d2-d7/a2-a6,-(a7)
    move.l d0,d3
    ; we print the high nibble first
.high:
    move.b d3,d4
    and.b #$f0,d4
    lsr.b #4,d4
    add.b #'0',d4 ; 0 -> '0'
    cmp.b #'9'+1,d4 ; >'9'?
    blt .ok1
    add.b #7,d4 ; '9'+1 -> 'A'
.ok1:
    move.b d4,d0
    jsr putc
    ; then the low nibble
.low:
    move.b d3,d4
    and.b #$0f,d4
    add.b #'0',d4
    cmp.b #'9'+1,d4
    blt .ok2
    add.b #7,d4
.ok2:
    move.b d4,d0
    jsr putc
.done:
    movem.l (a7)+,d2-d7/a2-a6
    rts

prompt:
    dc.b ">",0
intro:
    dc.b 10,"***   SIMPLE REPL   ***",10
    dc.b "  (empty line exits.)",10,10,0
goodbye:
    dc.b "Good bye!",10,0
error:
    dc.b "Not a command: ",0
internal_error:
    dc.b "Internal error!",10,0

; input buffer
buffer:
    blk.b 512,0
buffer_end:

;
; Command tables
; commands: is an array of strings with the last entry is the empty string
; command_impls: is an array of function pointers to implementations of commands
commands:
    dc.b 'quit', 0
    dc.b 'block', 0
    dc.b 'hello', 0
    dc.b 0 ; end of list
command_impls:
    dc.l quit_impl
    dc.l block_impl
    dc.l hello_impl
command_impls_end:

