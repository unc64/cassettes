; HIGHRISE for the UNC 16 (16K, no NIECE). Text mode, UNSCII as it comes: no
; characters of our own, no bitmap. A game of timing, after the arcade's stackers.
;
; Controls: SPACE stops the row (and starts, and restarts). RETURN takes the
; minor prize when it's offered.
;
; The rules. The tower is seven columns wide and fifteen rows high. A row of
; blocks slides from side to side; SPACE stops it, and the next row starts above
; it, faster. A block stays only where there's a block under it: the ones that
; overhang fall off, and the next row is as short as what was kept. Three blocks
; at the bottom, two at most from row 5, one from row 11. Miss the tower
; altogether and the game is over.
;
; Row 11 is the minor prize, 1,000 points: take it (RETURN) and the next round
; starts, or leave it (SPACE) and go on for the major prize at row 15, 5,000
; points and the next round. A missed row on the way up loses the game either
; way, as it always has. Every round is a step faster. A row is worth ten times
; its number for each block kept.
;
; The picture. A block is two characters wide and a row and a half high, 16 x 12
; dots, so fifteen rows fit in twenty-three text rows (22 1/2). Every text row
; of the tower shows the halves of two block rows, or of one: for each column
; the top half and the bottom half are looked up (TOPCELL, BOTCELL) and one of
; four UNSCII glyphs drawn twice: a space, the top half block $03, the bottom
; half $0B, the whole block $0F. Text rows are counted from the bottom here, as
; block rows are: text row t is screen row 23 - t.
;
; The tower is kept as bits: ROWS has a byte for each block row, bit c set for a
; block in column c (0 on the left). OVER is the same again for what's moving:
; the sliding row, then the blocks that fall. The picture is ROWS OR OVER.
;
; SPACE and RETURN are read from the keyboard matrix (chapter 11), and a press
; is the frame a key goes down: a key held down doesn't repeat, so the next row
; can't be stopped by the press that stopped this one.
;
; Sound is the beeper's timer (chapter 12), stepped once a frame: a tick for
; each step of the row, a note for each row stopped, a scale as the tower grows.
;
; Paced by FRAME ($C006), a tick a frame, no interrupts. The state is in the
; fast page, laid out with .res below.

SCREEN  = $0400
VMODE   = $C000
FRAME   = $C006
BORDER  = $C020
SPEAKER = $C031         ; bit 0 the timer's gate, bit 1 speaker data
TIMER_LO = $C032        ; the timer's divisor: 1,000,000 / pitch
TIMER_HI = $C033
KEYS    = $C060         ; the keyboard matrix, rows 0-8

; the ROM (chapter 13)
CLS     = $FF00
NUMSTR  = $FF18
PRNUM   = $FF1B
CURX    = $0200
CURY    = $0201

STEADY  = %00001000     ; VMODE bit 3: $A0 doesn't blink
PLAY    = %11           ; SPEAKER: gate on, data on: the timer reaches the speaker
K_SPACE = %00000001     ; in PRESS: KEYS row 0, bit 0
K_RETURN = %00010000    ; KEYS row 8, bit 4

; screen codes: UNSCII's own
G_TOP   = $03           ; the top half of a cell
G_BOT   = $0B           ; the bottom half
G_FULL  = $0F           ; all of it
HLINE   = $10
VLINE   = $11
CTL     = $12
CTR     = $13
CBL     = $14
CBR     = $15
TEE     = $16           ; a line with a branch to the right

WIDTH   = 7             ; columns
HEIGHT  = 15            ; block rows
TROWS   = 23            ; text rows of tower: HEIGHT * 3 / 2, rounded up
FIELDX  = 3             ; the tower's first screen column
FIELDW  = WIDTH * 2
BOTTOM  = 23            ; the screen row of text row 0
MINORAT = 11            ; rows stacked for the minor prize
MINOR   = 1000
MAJOR   = 5000
MINSPD  = 2             ; frames a step, at the fastest
FALLDLY = 3             ; frames a step for a falling block
RED     = 2
YELLOW  = 7

PANELX  = 21            ; the panel's text
NUMX    = 29            ; and its numbers
MSGY    = 18            ; the messages: rows 18-21
MSGH    = 4
MSGW    = 40 - PANELX

; states
TITLE   = 0
SLIDING = 1
FALLING = 2
CHOICE  = 3
OVERST  = 4
CHEER   = 5

; ---------------------------------------------------------------- fast page

        .org $00
STATE:  .res 1
ROWK:   .res 1          ; the block row being played, 0 the bottom
POS:    .res 1          ; the sliding row's left column
WID:    .res 1          ; its blocks, 1-3
DIR:    .res 1          ; 1 right, $FF left
TICK:   .res 1          ; frames until its next step
SPEED:  .res 1          ; frames a step
PIECE:  .res 1          ; the sliding row as bits
KEPT:   .res 1          ; the blocks that stayed, of the row just stopped
FALLM:  .res 1          ; the blocks falling
FALLK:  .res 1          ; and the row they've reached
WAIT:   .res 1          ; frames of a pause still to run
FLASH:  .res 1          ; the border flashes through the pause
ROUND:  .res 3          ; from 1; three bytes as `number` wants, two of them 0
SCORE:  .res 3          ; 24 bits
HISCORE: .res 3
KEYWAS: .res 1          ; SPACE and RETURN last frame
PRESS:  .res 1          ; and the ones that went down this frame
ROWS:   .res HEIGHT+1   ; the tower; the last is always 0 (above the top)
OVER:   .res HEIGHT+1   ; what's moving
PTR:    .res 2
PTR2:   .res 2
TMP:    .res 1
TOPM:   .res 1          ; drawrow: the bits of the text row's top halves
BOTM:   .res 1          ; and its bottom halves
TROW:   .res 1
NUMW:   .res 1          ; number: digits
SNDI:   .res 1          ; the next note: an offset into sounds
SNDT:   .res 1          ; frames left of the note playing; 0: silence
        .assert * <= $D0, "the fast page runs into the ROM's ($D0-$FE)"

; ---------------------------------------------------------------- start

        .org $0800
start:  STA HISCORE             ; A is 0 at start
        STA HISCORE+1
        STA HISCORE+2
        STA KEYWAS
        LDA #STEADY             ; reverse spaces stay put: blinking is up to us
        STA VMODE
        JSR drawscreen
        JSR title

; The main loop: wait for the frame counter to tick, then do one frame's work.
main:   LDA FRAME
@wait:  CMP FRAME
        BEQ @wait
        JSR keys
        JSR sndframe
        LDA STATE
        ASL A
        TAX
        LDA frames,X
        STA PTR2
        LDA frames+1,X
        STA PTR2+1
        JSR @go
        JMP main
@go:    JMP (PTR2)

frames: .word titleframe, slideframe, fallframe, choiceframe, overframe, cheerframe

; keys: PRESS = SPACE (bit 0) and RETURN (bit 4) if they went down this frame.
keys:   LDA KEYS
        AND #K_SPACE
        STA TMP
        LDA KEYS+8
        AND #K_RETURN
        ORA TMP
        TAX                     ; down now
        LDA KEYWAS
        EOR #$FF                ; up last frame
        STX KEYWAS
        AND KEYWAS
        STA PRESS
        RTS

; ---------------------------------------------------------------- title

; The title is the game's own screen with a row sliding along the bottom.
title:  LDA #TITLE
        STA STATE
        JSR quiet
        JSR cleartower
        LDX #<titletxt
        LDY #>titletxt
        JSR message
        LDA #0
        STA ROWK
        STA POS
        LDA #1
        STA DIR
        LDA #3
        STA WID
        LDA #6
        STA SPEED
        STA TICK
        JMP setpiece

titleframe:
        LDX #<SCREEN+[MSGY+3]*40+PANELX     ; PRESS SPACE
        LDY #>SCREEN+[MSGY+3]*40+PANELX
        LDA #11
        JSR blink
        LDA PRESS
        AND #K_SPACE
        BNE newgame
        JMP step

; ---------------------------------------------------------------- a new game

newgame:
        LDA #0
        STA SCORE
        STA SCORE+1
        STA SCORE+2
        STA ROUND+1
        STA ROUND+2
        STA BORDER
        LDA #1
        STA ROUND
        JSR showscore
        ; fall through

; newround: an empty tower, and the first row.
newround:
        JSR cleartower
        JSR clearmsg
        LDA #2
        STA NUMW
        LDA #ROUND
        LDX #NUMX
        LDY #15
        JSR number
        LDY #SNDSTART
        JSR sound
        LDA #0
        STA ROWK
        LDA #3
        STA WID
        ; fall through

; newrow: the row at ROWK starts to slide: from the left on even rows, from the
; right on odd ones, no wider than the row allows, as fast as the row and the
; round say.
newrow: LDX ROWK
        LDA WID
        CMP widest,X
        BCC @wide
        LDA widest,X
        STA WID
@wide:  LDA speeds,X            ; the first round's speed, plus 1
        SEC
        SBC ROUND
        BCC @fast
        CMP #MINSPD
        BCS @speed
@fast:  LDA #MINSPD
@speed: STA SPEED
        STA TICK
        LDY #0
        LDA #1
        STA DIR
        TXA
        LSR A
        BCC @from
        LDA #$FF
        STA DIR
        LDA #WIDTH
        SEC
        SBC WID
        TAY
@from:  STY POS
        LDA #SLIDING
        STA STATE
        JMP setpiece

; ---------------------------------------------------------------- playing

; The key comes first, so that the row stops where the player saw it.
slideframe:
        LDA PRESS
        AND #K_SPACE
        BNE stop
        ; fall through

; step: count the frame; when the time's up, move the row one column, turning
; at the walls.
step:   DEC TICK
        BNE stepped
        LDA SPEED
        STA TICK
        LDA POS
        CLC
        ADC DIR
        BMI @turn               ; off the left
        CLC
        ADC WID
        CMP #WIDTH+1
        BCC @go
@turn:  LDA DIR                 ; off the right
        EOR #$FE                ; 1 and $FF change places
        STA DIR
@go:    LDA POS
        CLC
        ADC DIR
        STA POS
        JSR tick
        ; fall through

; setpiece: PIECE = WID blocks from column POS, into OVER and onto the screen.
setpiece:
        LDX WID
        LDA wmask,X
        LDX POS
        BEQ @put
@shift: ASL A
        DEX
        BNE @shift
@put:   STA PIECE
        LDX ROWK
        STA OVER,X
        JMP drawcell
stepped: RTS

; stop: the row stops. What has a block under it joins the tower; the rest
; falls.
stop:   LDX ROWK
        LDA #0
        STA OVER,X
        LDA PIECE
        CPX #0
        BEQ @keep               ; the bottom row: the floor holds all of it
        AND ROWS-1,X
@keep:  STA ROWS,X
        STA KEPT
        EOR PIECE
        STA FALLM
        BEQ @whole
        STA OVER,X
        STX FALLK
        LDA #FALLDLY
        STA WAIT
        LDA #FALLING
        STA STATE
        LDY #SNDSLIP
        JSR sound
        LDX ROWK
        JMP drawcell
@whole: JSR drawcell
        JSR rownote
        JMP settled

; The blocks that overhang drop a row at a time. One with a block under it, or
; on the floor, is gone at the next step.
fallframe:
        DEC WAIT
        BNE stepped
        LDA #FALLDLY
        STA WAIT
        LDX FALLK
        LDA #0
        STA OVER,X
        JSR drawcell
        LDX FALLK
        BEQ settled             ; the floor
        DEX
        LDA ROWS,X
        EOR #$FF
        AND FALLM               ; the ones with nothing under them
        STA FALLM
        BEQ settled
        STA OVER,X
        STX FALLK
        JMP drawcell

; settled: the row is in the tower. Nothing kept: the game is over. Otherwise
; score it, and on to the next row or a prize.
settled:
        LDA KEPT
        BNE @some
        JMP gameover
@some:  LDY #0                  ; count the blocks
@count: LSR A
        BCC @zero
        INY
@zero:  BNE @count
        STY WID
@score: LDX ROWK
        LDA rowpts,X
        LDX #0
        JSR addpts
        DEY
        BNE @score
        JSR showscore
        INC ROWK
        LDA ROWK
        CMP #HEIGHT
        BEQ major
        CMP #MINORAT
        BEQ minor
        JMP newrow

; ---------------------------------------------------------------- prizes

; minor: the minor prize is offered. A short pause first, so that a second tap
; meant for the row isn't taken for an answer.
minor:  LDX #<minortxt
        LDY #>minortxt
        JSR message
        LDY #SNDMINOR
        JSR sound
        LDA #25
        STA WAIT
        LDA #CHOICE
        STA STATE
        RTS

choiceframe:
        LDA WAIT
        BEQ @ask
        DEC WAIT
        RTS
@ask:   LDA PRESS
        AND #K_RETURN
        BNE @take
        LDA PRESS
        AND #K_SPACE
        BEQ @done
        JSR clearmsg            ; on, for the major prize
        JMP newrow
@take:  LDA #<MINOR
        LDX #>MINOR
        JSR addpts
        LDX #<tooktxt
        LDY #>tooktxt
        LDA #0
        BEQ cheer
@done:  RTS

; major: the top.
major:  LDA #<MAJOR
        LDX #>MAJOR
        JSR addpts
        LDY #SNDMAJOR
        JSR sound
        LDX #<majortxt
        LDY #>majortxt
        LDA #1
        ; fall through

; cheer: the message at X/Y, the score, and a pause (flashing if A isn't 0)
; before the next round.
cheer:  STA FLASH
        JSR message
        JSR showscore
        LDA #110
        STA WAIT
        LDA #CHEER
        STA STATE
        RTS

cheerframe:
        LDA FLASH
        BEQ @count
        LDX #0
        LDA WAIT
        AND #%1000
        BEQ @dark
        LDX #YELLOW
@dark:  STX BORDER
@count: DEC WAIT
        BNE @done
        LDA #0
        STA BORDER
        INC ROUND
        BNE @round
        DEC ROUND               ; round 255 is the last one there is
@round: JMP newround
@done:  RTS

; ---------------------------------------------------------------- game over

gameover:
        LDY #SNDOVER
        JSR sound
        LDA #OVERST
        STA STATE
        LDA #50                 ; a second's pause before SPACE counts
        STA WAIT
        LDA #RED
        STA BORDER
        LDX #<overtxt
        LDY #>overtxt
        JSR message
        LDA HISCORE             ; HISCORE - SCORE: carry set if no new high
        CMP SCORE
        LDA HISCORE+1
        SBC SCORE+1
        LDA HISCORE+2
        SBC SCORE+2
        BCS @done
        LDX #2
@copy:  LDA SCORE,X
        STA HISCORE,X
        DEX
        BPL @copy
        LDX #<hightxt
        LDY #>hightxt
        JSR prlist
        JMP showhigh
@done:  RTS

overframe:
        LDA WAIT
        BEQ @ready
        DEC WAIT
        BNE @done
        LDA #0
        STA BORDER
        LDX #<againtxt
        LDY #>againtxt
        JMP prlist
@ready: LDX #<SCREEN+[MSGY+3]*40+PANELX     ; SPACE TO PLAY
        LDY #>SCREEN+[MSGY+3]*40+PANELX
        LDA #13
        JSR blink
        LDA PRESS
        AND #K_SPACE
        BEQ @done
        JMP newgame
@done:  RTS

; ---------------------------------------------------------------- score

; addpts: SCORE += A (low) and X (high). Keeps Y.
addpts: CLC
        ADC SCORE
        STA SCORE
        TXA
        ADC SCORE+1
        STA SCORE+1
        BCC @done
        INC SCORE+2
@done:  RTS

showhigh:
        LDA #HISCORE
        LDY #13
        BNE six
showscore:
        LDA #SCORE
        LDY #11
six:    LDX #6
        STX NUMW
        LDX #NUMX
        ; fall through

; number: print the 24-bit number at fast-page address A at column X, row Y,
; NUMW digits wide with leading zeros (NUMSTR and PRNUM, chapter 13).
number: STX CURX
        STY CURY
        TAX
        LDY 1,X                 ; the middle byte
        LDA 2,X                 ; the high byte...
        PHA
        LDA 0,X                 ; ...waits while the low byte goes in X
        TAX
        PLA
        JSR NUMSTR
        LDA NUMW
        JMP PRNUM

; ---------------------------------------------------------------- sound

; One voice: the beeper's timer plays each note by itself. An effect is a list
; of notes at sounds+offset: a length in frames, then the timer's divisor; a
; length of 0 ends it. sndframe, once a frame, starts the next note when a
; note's time is up, and closes the gate when the effect ends.

; tick: the row's step, a frame long and higher with every column. Left out if
; anything else is playing, and on the title screen.
tick:   LDA SNDT
        BNE toned
        LDA STATE
        CMP #SLIDING
        BNE toned
        LDA POS
        ASL A
        TAX
        LDA ticks,X
        LDY ticks+1,X
        LDX #1
        BNE tone

; rownote: a row stopped whole: the scale's note for ROWK.
rownote:
        LDA ROWK
        ASL A
        TAX
        LDA scale,X
        LDY scale+1,X
        LDX #5
        ; fall through

; tone: one note by itself: the divisor A (low) and Y (high), for X frames.
tone:   STA TIMER_LO
        STY TIMER_HI
        STX SNDT
        LDA #PLAY
        STA SPEAKER
        LDA #SNDEND
        STA SNDI
toned:  RTS

; sound: start the effect at sounds+Y. Its first note plays from this frame.
sound:  STY SNDI
        ; fall through

; note: start the note at sounds+SNDI, or end the effect at its 0.
note:   LDY SNDI
        LDA sounds,Y            ; the length
        BEQ quiet
        STA SNDT
        LDA sounds+1,Y
        STA TIMER_LO
        LDA sounds+2,Y
        STA TIMER_HI            ; the timer takes it at its next half-wave: no click
        LDA #PLAY
        STA SPEAKER
        INY
        INY
        INY
        STY SNDI
        RTS

; quiet: gate and data off, nothing playing.
quiet:  LDA #0
        STA SPEAKER
        STA SNDT
        RTS

; sndframe: once a frame, a few cycles. Counts the note down; at 0, the next.
sndframe:
        LDA SNDT
        BEQ @done               ; silence
        DEC SNDT
        BEQ note
@done:  RTS

; ---------------------------------------------------------------- drawing

; cleartower: no blocks, anywhere, and the picture of it.
cleartower:
        LDX #HEIGHT*2+1         ; ROWS and OVER, one after the other
        LDA #0
@clear: STA ROWS,X
        DEX
        BPL @clear
        LDA #TROWS-1
        STA TMP
@row:   LDX TMP
        JSR drawrow
        DEC TMP
        BPL @row
        RTS

; drawcell: draw block row X: the two text rows it shows in.
drawcell:
        LDA cellrow,X
        PHA
        TAX
        JSR drawrow
        PLA
        TAX
        INX
        ; fall through

; drawrow: draw text row X of the tower (0 the bottom): for each column, the
; glyph for its top half and its bottom half, twice.
drawrow:
        LDY topcell,X
        LDA ROWS,Y
        ORA OVER,Y
        STA TOPM
        LDY botcell,X
        LDA ROWS,Y
        ORA OVER,Y
        STA BOTM
        LDA trowlo,X
        STA PTR
        LDA trowhi,X
        STA PTR+1
        LDY #0
@col:   LDA #0
        LSR BOTM
        ROL A
        LSR TOPM
        ROL A                   ; bit 1 the bottom half, bit 0 the top
        TAX
        LDA halves,X
        STA (PTR),Y
        INY
        STA (PTR),Y
        INY
        CPY #FIELDW
        BNE @col
        RTS

; drawscreen: everything that stays: the tower's frame, the prize marks, the
; panel.
drawscreen:
        JSR CLS
        LDX #FIELDW+1
        LDA #HLINE
@lines: STA SCREEN+FIELDX-1,X
        STA SCREEN+24*40+FIELDX-1,X
        DEX
        BNE @lines
        LDA #CTL
        STA SCREEN+FIELDX-1
        LDA #CTR
        STA SCREEN+FIELDX+FIELDW
        LDA #CBL
        STA SCREEN+24*40+FIELDX-1
        LDA #CBR
        STA SCREEN+24*40+FIELDX+FIELDW
        LDX #TROWS-1
@sides: LDA trowlo,X
        STA PTR
        LDA trowhi,X
        STA PTR+1
        LDA #VLINE
        LDY #FIELDW
        STA (PTR),Y
        DEC PTR                 ; the column before the tower: never across a page
        LDY #0                  ; (see the .assert by trowlo)
        STA (PTR),Y
        DEX
        BPL @sides
        LDA #TEE
        STA SCREEN+MAJORY*40+FIELDX+FIELDW
        STA SCREEN+MINORY*40+FIELDX+FIELDW
        LDX #<paneltxt
        LDY #>paneltxt
        JSR prlist
        JSR showscore
        JMP showhigh

; message: clear the message rows and print the records at X (low) / Y (high).
message:
        TXA
        PHA
        TYA
        PHA
        JSR clearmsg
        PLA
        TAY
        PLA
        TAX
        ; fall through

; prlist: print records from X (low) / Y (high) until a column of $FF.
; A record is: column, row, text, 0.
prlist: STX PTR2
        STY PTR2+1
@rec:   LDY #0
        LDA (PTR2),Y
        CMP #$FF
        BEQ @done
        PHA
        INY
        LDA (PTR2),Y
        TAX
        PLA
        JSR at                  ; PTR = the first cell
        LDA #2                  ; PTR2 = the text
        JSR @skip
        LDY #0
@char:  LDA (PTR2),Y
        BEQ @end
        STA (PTR),Y
        INY
        BNE @char
@end:   INY                     ; past the 0: on to the next record
        TYA
        JSR @skip
        JMP @rec
@skip:  CLC                     ; PTR2 += A
        ADC PTR2
        STA PTR2
        BCC @done
        INC PTR2+1
@done:  RTS

; clearmsg: spaces over the message rows.
clearmsg:
        LDX #MSGY+MSGH-1
@row:   LDA #PANELX
        JSR at
        LDA #' '
        LDY #MSGW-1
@cell:  STA (PTR),Y
        DEY
        BPL @cell
        DEX
        CPX #MSGY
        BCS @row
        RTS

; at: PTR = the screen address of column A, row X.
at:     CLC
        ADC rowlo,X
        STA PTR
        LDA rowhi,X
        ADC #0
        STA PTR+1
        RTS

; blink: every 16 frames, flip A cells from X (low) / Y (high) between normal
; and reverse video.
blink:  STX PTR
        STY PTR+1
        TAY
        LDA FRAME
        AND #15
        BNE @done
        DEY
@loop:  LDA (PTR),Y
        EOR #$80
        STA (PTR),Y
        DEY
        BPL @loop
@done:  RTS

; ---------------------------------------------------------------- data

halves: .byte ' ', G_TOP, G_BOT, G_FULL

wmask:  .byte 0, %1, %11, %111

; The widest a row may be, by block row: three, two from row 5, one from row 11.
widest: .fill 4, 3
        .fill 6, 2
        .fill 5, 1
        .assert * - widest == HEIGHT

; Frames a step in the first round, plus 1 (newrow takes the round off).
speeds: .byte 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4, 3
        .assert * - speeds == HEIGHT

; Points for a block kept, by block row.
rowpts: .rept HEIGHT, n
        .byte [n + 1] * 10
        .endr

; Block row k is 12 lines high, a text row 8: it starts in text row 3k / 2 and
; ends in the next. Text row t shows block row (2t + 1) / 3 in its top half and
; 2t / 3 in its bottom half; the top of the last is row 15, which is never there.
cellrow:
        .rept HEIGHT, k
        .byte k * 3 / 2
        .endr
topcell:
        .rept TROWS, t
        .byte [t * 2 + 1] / 3
        .endr
botcell:
        .rept TROWS, t
        .byte t * 2 / 3
        .endr

; Where text row t of the tower starts on the screen.
trowlo: .rept TROWS, t
        .byte <SCREEN + [BOTTOM - t] * 40 + FIELDX
        .assert [[SCREEN + [BOTTOM - t] * 40 + FIELDX] & $FF] != 0, "drawscreen steps back a column"
        .endr
trowhi: .rept TROWS, t
        .byte >SCREEN + [BOTTOM - t] * 40 + FIELDX
        .endr

rowlo:  .rept 25, n
        .byte <SCREEN + n * 40
        .endr
rowhi:  .rept 25, n
        .byte >SCREEN + n * 40
        .endr

; The screen rows the prize marks sit by: the text row a block row starts in.
MAJORY  = BOTTOM - [HEIGHT - 1] * 3 / 2
MINORY  = BOTTOM - [MINORAT - 1] * 3 / 2

; The step's tick, by column: timer divisors, low notes.
ticks:  .irp hz, 196, 220, 262, 294, 330, 392, 440
        .word 1000000 / hz
        .endr

; A row stopped whole: two octaves of C major, a note a row.
scale:  .irp hz, 523, 587, 659, 698, 784, 880, 988, 1047, 1175, 1319, 1397, 1568, 1760, 1976, 2093
        .word 1000000 / hz
        .endr

; Sound effects for `sound`: notes of a length in frames and a timer divisor
; (1,000,000 / pitch), and a 0 to end. Offsets fit in Y.
sounds:
SNDEND = * - sounds             ; nothing: where `tone` leaves SNDI
        .byte 0
SNDSTART = * - sounds           ; a round begins: up a chord
        .irp hz, 523, 659, 784
        .byte 3
        .word 1000000 / hz
        .endr
        .byte 6
        .word 1000000 / 1047
        .byte 0
SNDSLIP = * - sounds            ; blocks lost: a slide down
        .rept 10, n
        .byte 1
        .word 900 + n * 260
        .endr
        .byte 0
SNDMINOR = * - sounds           ; the minor prize: a call, waiting for an answer
        .irp hz, 784, 1047, 784, 1047, 1319
        .byte 4
        .word 1000000 / hz
        .endr
        .byte 0
SNDMAJOR = * - sounds           ; the top: a fanfare
        .irp hz, 523, 659, 784, 1047, 784, 1047, 1319, 1568, 1319, 1568
        .byte 5
        .word 1000000 / hz
        .endr
        .byte 30
        .word 1000000 / 2093
        .byte 0
SNDOVER = * - sounds            ; a long slide down, wobbling, and a thud
        .rept 28, n
        .byte 1
        .word 1400 + n * n * 6 + sin(n * 40, 100 + n * 10)
        .endr
        .byte 10
        .word 9000
        .byte 0
        .assert * - sounds <= 256, "sound offsets must fit in Y"

paneltxt:
        .byte FIELDX+FIELDW+1, MAJORY
        .byte HLINE
        .text " MAJOR PRIZE  5000"
        .byte 0
        .byte FIELDX+FIELDW+1, MINORY
        .byte HLINE
        .text " MINOR PRIZE  1000"
        .byte 0
        .byte PANELX, 4
        .text "H I G H R I S E"
        .byte 0
        .byte PANELX, 5
        .fill 15, HLINE
        .byte 0
        .byte PANELX, 11
        .text "SCORE"
        .byte 0
        .byte PANELX, 13
        .text "HIGH"
        .byte 0
        .byte PANELX, 15
        .text "ROUND   01"
        .byte 0
        .byte PANELX, 23
        .text "SPACE STOPS THE ROW"
        .byte 0
        .byte $FF

titletxt:
        .byte PANELX, MSGY
        .text "STACK THE ROWS"
        .byte 0
        .byte PANELX, MSGY+1
        .text "TO THE TOP"
        .byte 0
        .byte PANELX, MSGY+3
        .text "PRESS SPACE"
        .byte 0
        .byte $FF

minortxt:
        .byte PANELX, MSGY
        .text "THE MINOR PRIZE!"
        .byte 0
        .byte PANELX, MSGY+2
        .text "RETURN  TAKE IT"
        .byte 0
        .byte PANELX, MSGY+3
        .text "SPACE   GO ON"
        .byte 0
        .byte $FF

tooktxt:
        .byte PANELX, MSGY
        .text "THE MINOR PRIZE"
        .byte 0
        .byte PANELX, MSGY+1
        .text "1000 POINTS"
        .byte 0
        .byte $FF

majortxt:
        .byte PANELX, MSGY
        .text "THE MAJOR PRIZE!"
        .byte 0
        .byte PANELX, MSGY+1
        .text "5000 POINTS"
        .byte 0
        .byte $FF

overtxt:
        .byte PANELX, MSGY
        .text "GAME OVER"
        .byte 0
        .byte $FF

hightxt:
        .byte PANELX, MSGY+1
        .text "NEW HIGH SCORE"
        .byte 0
        .byte $FF

againtxt:
        .byte PANELX, MSGY+3
        .text "SPACE TO PLAY"
        .byte 0
        .byte $FF

        .assert * <= $4000, "past the end of a UNC 16's memory"
