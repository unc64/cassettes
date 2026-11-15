; SALVO for the UNC 16 (16K, no NIECE). A battle of tanks, in turns, against the machine.
;
; Controls: the cursor keys move the cursor. SPACE picks the tank under it; with a tank
; picked, SPACE on a dotted square drives there and SPACE on an enemy shown in reverse
; fires at it. N picks your next tank, B buys one, RETURN ends your turn.
;
; The rules. Twelve squares by ten, five tanks a side. A turn is five moves, spent on any
; tanks in any order: a square driven is a move (three squares at most in one go, round
; the other tanks), a shot is a move, and so is buying a tank, which also costs $4,000 and
; arrives in your three home columns. A shot reaches three squares, any direction, if no
; tank stands in the line; three hits destroy a tank. Drive over a coin for $2,000 and
; over a spanner to mend a tank; both turn up again somewhere else. The side with no
; tanks left has lost.
;
; The picture is the bitmap in mixed mode: 168 lines, the board at 16 x 16 a square with
; the panel beside it (its letters copied out of the character ROM), and the last four
; text rows under it for the messages. A square is always redrawn whole, from what the
; board says is on it: the tank, coin or spanner, then the marks laid over it (the dotted
; ring of a square in reach, reverse for a target, a frame round the picked tank, the
; cursor's corners). The shell is drawn with the shifter, EORed on and off again.
;
; The board is kept 14 x 12, with a wall all round, so a neighbour is a square's number
; plus or minus 1, 13, 14 or 15 and nothing has to ask where the edge is. It sits, with
; the other tables a square long, under the bitmap in the text screen's hidden rows.
;
; The enemy tries every move, shot and purchase it has, scores each, and takes the best;
; then again, until its five moves are gone. A score is a 16-bit number, four to the
; point, started at 8,000 so that it never goes below zero.
;
; Sound is the beeper: the timer for the notes, stepped once a frame, and NOISE by hand
; for the hits.

SCREEN  = $0400
VMODE   = $C000
FRAME   = $C006
KBD_STROBE = $C011
BITMAP  = $C023
TEXTROWS = $C024
BEEPER  = $C030
SPEAKER = $C031         ; bit 0 the timer's gate, bit 1 speaker data
TIMER_LO = $C032        ; the timer's divisor: 1,000,000 / pitch
TIMER_HI = $C033
NOISE   = $C034
SHIFT_IN = $C050
SHIFT_AMT = $C051
SHIFT_OUT = $C052
CHARROM = $D000

; the ROM (chapter 13)
CLS     = $FF00
CHROUT  = $FF03
GETKEY  = $FF06
RND     = $FF12
RNDSEED = $FF1E

BMPAGE  = $25           ; the bitmap: $2500-$3F3F, 168 lines of it shown
BM      = BMPAGE*256
MIXED   = %00000110     ; VMODE: the bitmap, with text rows under it

W       = 14            ; the board with its wall: 14 x 12
CELLS   = W*12
MAXT    = 32            ; tanks, both sides together
COIN    = $80           ; on a square: 0 nothing, 1-MAXT a tank (its number + 1),
TOOL    = $81           ; these two, and
WALL    = $FF           ; the wall
REACH   = 1             ; FLAGS: a square the picked tank can drive to,
TARGET  = 2             ; a tank it can hit,
ONPATH  = 4             ; a square of the drive being made
PRICE   = 4             ; a tank, in thousands
BOUNTY  = 2             ; a coin
BALL    = $94           ; the ROM's ball and ring: a move left, a move spent
RING    = $95
ROW22   = SCREEN+22*40  ; the three message rows
ROW23   = SCREEN+23*40
ROW24   = SCREEN+24*40

; ---------------------------------------------------------------- the fast page
        .org $0000
PTR:    .res 2          ; into the bitmap
SRC:    .res 2          ; a sprite, a string
GP:     .res 2          ; a glyph in the character ROM
MP:     .res 2          ; a message kept for later
SND:    .res 2          ; the next note of the tune playing
SNDT:   .res 1          ; frames left of this one; 0: silence
T0:     .res 1
T1:     .res 1
T2:     .res 1
T3:     .res 1
T5:     .res 1
SX:     .res 1          ; saved registers
SY:     .res 1
CB:     .res 32         ; a square being put together, 16 rows of two bytes
DCP:    .res 1          ; and which square
TXC:    .res 1          ; where the next letter goes on the bitmap: column, row
TXR:    .res 1
TXINV:  .res 1          ; $FF: in reverse
MSGX:   .res 1          ; the column of the message being written
TURN:   .res 1          ; 0 yours, 1 the enemy's
MOVES:  .res 1          ; moves left this turn
ROUND:  .res 1
WINNER: .res 1          ; 0 nobody yet, 1 you, 2 the enemy
CASH:   .res 2          ; in thousands: yours, the enemy's
CURP:   .res 1          ; the cursor's square
CURON:  .res 1          ; and whether it's lit
BLINK:  .res 1
SELT:   .res 1          ; the picked tank; $FF: none
SELP:   .res 1          ; its square; 0: none
BMAX:   .res 1          ; the search for squares in reach
BCUR:   .res 1
BNEW:   .res 1
BK:     .res 1
BN:     .res 1
QH:     .res 1
QN:     .res 1
MX:     .res 1          ; a square's column and row, to measure from
MY:     .res 1
MTEAM:  .res 1          ; the side to measure to
MBEST:  .res 1
DTEAM:  .res 1          ; a square to deploy on
DCOL:   .res 1
DP:     .res 1
DI:     .res 1
DJ:     .res 1
DBEST:  .res 1
DBM:    .res 1
MT:     .res 1          ; a drive: the tank, where to, the steps
MD:     .res 1
MN:     .res 1
MK:     .res 1
MPICK:  .res 1
ST:     .res 1          ; a shot: the gun, the target, its square
SG:     .res 1
SB:     .res 1
SDX:    .res 1
SDY:    .res 1
SHX:    .res 1          ; the shell
SHY:    .res 1
SN:     .res 1
AIT:    .res 1          ; the enemy's thinking: the tank, its square and armour
AIP:    .res 1
AIH:    .res 1
AIR:    .res 1          ; how many of yours it can hit (and be hit by)
AID:    .res 1          ; the square it tries
EI:     .res 1
MI:     .res 1
STEPS:  .res 1
GOTM:   .res 1
GOTT:   .res 1
SAVEG:  .res 1
HPA:    .res 1
HCNT:   .res 1
MAXD:   .res 1
NEAR:   .res 1
TD2:    .res 1
NHUM:   .res 1
NAI:    .res 1
TBASE:  .res 2          ; a score: what every move of this tank starts from,
SC:     .res 2          ; the one being worked out,
BSC:    .res 2          ; the best so far,
BTYPE:  .res 1          ; and what it was: 0 nothing, 1 drive, 2 fire, 3 buy
BTANK:  .res 1
BARG:   .res 1
        .assert * <= $D0, "the fast page from $D0 up is the ROM's"

; ------------------------------------------------- under the bitmap: rows 0-20
        .org SCREEN
GRID:   .res CELLS      ; what's on each square
FLAGS:  .res CELLS      ; the marks drawn over it
DIST:   .res CELLS      ; the search: steps from the tank, $FF not reached
PARENT: .res CELLS      ; and the square it was reached from
PX:     .res CELLS      ; a square's column, 0-11, and
        .assert * <= SCREEN+21*40, "the tables run into the message rows"

; ---------------------------------------------------------------- the program
        .org $0800
start:  LDX #$FF
        TXS
        LDA #0
        STA SPEAKER
        STA VMODE
        JSR CLS
        LDA #<title
        STA MP
        LDA #>title
        STA MP+1
@page:  LDY #0              ; the title page
        LDA (MP),Y
        BEQ @key
        JSR CHROUT
        INC MP
        BNE @page
        INC MP+1
        BNE @page
@key:   JSR GETKEY
        CMP #' '
        BNE @key
        LDX NOISE           ; the moment SPACE went down: a different battle each time
        LDY NOISE
        JSR RNDSEED
        JSR mode            ; the bitmap over the text screen's first 21 rows, which
        JSR tables          ; are the board's from here on

; A new battle.
newgame:
        LDX #CELLS-1
@grid:  LDY #0              ; the board: empty inside the wall
        LDA PX,X
        CMP #12
        BCS @wall
        LDA PY,X
        CMP #10
        BCC @put
@wall:  LDY #WALL
@put:   TYA
        STA GRID,X
        LDA #0
        STA FLAGS,X
        DEX
        CPX #$FF
        BNE @grid
        LDX #MAXT-1
@none:  STA THP,X
        DEX
        BPL @none
        STA TURN
        STA WINNER
        STA SELP
        STA SNDT
        STA TXINV
        LDX #0
@tanks: STX T3              ; five a side, facing each other
        TXA
        AND #1
        TAY
        LDA starts,X
        TAX
        JSR spawn
        LDX T3
        INX
        CPX #10
        BNE @tanks
        LDA #COIN
        STA GRID+3*W+5
        STA GRID+8*W+8
        LDA #TOOL
        STA GRID+5*W+6
        STA GRID+7*W+7
        LDA #BOUNTY
        STA CASH
        STA CASH+1
        LDA #5
        STA MOVES
        LDA #1
        STA ROUND
        STA CURON
        LDA #$FF
        STA SELT
        LDA #5*W+2          ; the cursor on your middle tank
        STA CURP
        JSR picture
        LDX #<m_start
        LDY #>m_start
        JSR msg
        JMP yours

; ---------------------------------------------------------------- your turn
yours:  BIT KBD_STROBE      ; keys pressed while the enemy moved don't count
        LDA #1
        STA CURON
        LDX CURP
        JSR drawcell
        JSR panel
hloop:  JSR waitframe
        DEC BLINK
        BPL @key
        LDA #15             ; the cursor blinks
        STA BLINK
        LDA CURON
        EOR #1
        STA CURON
        LDX CURP
        JSR drawcell
@key:   LDA KBD_STROBE
        BPL hloop
        AND #$7F
        CMP #28
        BCC @other
        CMP #32
        BCS @other
        TAX                 ; a cursor key
        LDA CURP
        CLC
        ADC curstep-28,X
        TAX
        LDA GRID,X
        CMP #WALL
        BEQ hloop
        LDA CURP
        STX CURP
        TAX
        JSR drawcell        ; off the old square,
        JSR curshow         ; on to the new
        JSR info
        JMP hloop
@other: CMP #' '
        BEQ act
        CMP #13
        BEQ endturn
        CMP #'B'
        BNE @n
        JMP buy
@n:     CMP #'N'
        BNE hloop
        LDX SELT            ; the next of your tanks after the picked one
        LDY #MAXT
@next:  INX
        CPX #MAXT
        BCC @in
        LDX #0
@in:    LDA THP,X
        BEQ @no
        LDA TTEAM,X
        BEQ pick
@no:    DEY
        BNE @next
        JMP hloop

; The enemy's turn follows yours.
endturn:
        LDA #$FF
        STA SELT
        JSR sethl
        JMP theirs

; PICK: tank X, one of yours, is the picked one, and the cursor goes to it.
pick:   STX SELT            ; one of yours: pick it, and put the cursor on it
        LDA CURP
        LDY TPOS,X
        STY CURP
        TAX
        JSR drawcell
        JSR curshow
        JSR sethl
        JSR info
        LDX #<t_pick
        LDY #>t_pick
        JSR play
        JMP hloop

; SPACE: pick a tank, drive, or fire.
act:    LDX CURP
        LDA GRID,X
        BEQ @drive
        BMI @drive
        TAY
        DEY                 ; a tank: Y is its number
        LDA TTEAM,Y
        BNE @fire
        TYA
        TAX
        JMP pick
@fire:  LDA SELT
        BMI @nosel
        LDA FLAGS,X
        AND #TARGET
        BEQ @noshot
        STY SG
        JSR clrhl
        LDX SELT
        LDY SG
        JSR doshoot
        JMP acted
@drive: LDA SELT
        BMI @nosel
        LDA FLAGS,X
        AND #REACH
        BEQ @far
        STX MD
        JSR clrhl
        LDX SELT
        LDA MD
        JSR domove
        LDA CURP            ; the cursor rides along
        LDX SELT
        LDY TPOS,X
        STY CURP
        TAX
        JSR drawcell
        JMP acted
@nosel: LDX #<m_nosel
        LDY #>m_nosel
        BNE @say
@noshot:
        LDX #<m_noshot
        LDY #>m_noshot
        BNE @say
@far:   LDX #<m_far
        LDY #>m_far
@say:   JSR msg
grumble:
        LDX #<t_no
        LDY #>t_no
        JSR play
        JMP hloop

; B: buy a tank, on the free home square nearest the enemy.
buy:    LDA CASH
        CMP #PRICE
        BCS @rich
        LDX #<m_poor
        LDY #>m_poor
        BNE @say
@rich:  JSR freeslot
        BCS @full
        LDA #0
        JSR deploy
        TXA
        BNE @go
@full:  LDX #<m_full
        LDY #>m_full
@say:   JSR msg
        JMP grumble
@go:    JSR clrhl
        LDX DBEST
        JSR dobuy
        STY SELT            ; the new tank is the picked one

; After anything you did.
acted:  JSR panel
        LDA WINNER
        BEQ @on
        JMP over
@on:    JSR sethl
        JSR curshow
        LDA MOVES
        BEQ @spent
        JMP hloop
@spent: LDA #22             ; the fifth move: the turn ends by itself
        JSR delay
        JMP endturn

; ---------------------------------------------------------------- the enemy's turn
theirs: LDA #0
        STA CURON
        LDX CURP
        JSR drawcell
        LDA #1
        STA TURN
        LDA #5
        STA MOVES
        JSR panel
        LDA #20
        JSR delay
@more:  LDA MOVES
        BEQ @done
        JSR think
        LDA BTYPE
        BEQ @done
        LDX BTANK
        CMP #1
        BNE @n1
        LDA BARG
        JSR domove
        JMP @did
@n1:    CMP #2
        BNE @n2
        LDY BARG
        JSR doshoot
        JMP @did
@n2:    LDX BARG
        JSR dobuy
@did:   JSR panel
        LDA WINNER
        BNE over
        LDA #7
        JSR delay
        JMP @more
@done:  LDA #0
        STA TURN
        LDA #5
        STA MOVES
        INC ROUND
        LDX #<m_yours
        LDY #>m_yours
        JSR msg
        JMP yours

; All of one side's tanks are gone.
over:   LDX #<m_won
        LDY #>m_won
        LDA WINNER
        CMP #1
        BEQ @say
        LDX #<m_lost
        LDY #>m_lost
@say:   JSR msg
        LDX #<m_again
        LDY #>m_again
        JSR msg
        LDX #<t_won
        LDY #>t_won
        LDA WINNER
        CMP #1
        BEQ @tune
        LDX #<t_lost
        LDY #>t_lost
@tune:  JSR play
        BIT KBD_STROBE
@wait:  JSR waitframe
        LDA KBD_STROBE
        BPL @wait
        CMP #' '+$80
        BNE @wait
        JMP newgame

; ---------------------------------------------------------------- what a move does

; DOMOVE: tank X drives to square A, which must be in its reach: a square at a time,
; taking what it drives over.
domove: STX MT
        STA MD
        JSR bfst            ; the way there is the search's
        LDX MD
        LDA DIST,X
        STA MN
        TAY
@back:  LDA FLAGS,X         ; from the far end back to the tank, marking the way
        ORA #ONPATH
        STA FLAGS,X
        DEY
        BMI @go
        TXA
        STA PATH,Y
        LDA PARENT,X
        TAX
        BNE @back
@go:    LDA #0
        STA MK
@step:  LDX MK
        LDA PATH,X
        STA T2              ; the next square
        LDX MT
        LDA TPOS,X
        STA T3              ; and the one it's on
        TAX
        LDY T2
        SEC                 ; turn to face the way it's going: the step is
        LDA PY,Y            ; (dx, dy), each -1, 0 or 1
        SBC PY,X
        CLC
        ADC #1
        STA T0
        ASL A
        ADC T0
        STA T0              ; 3 * (dy + 1)
        SEC
        LDA PX,Y
        SBC PX,X
        CLC
        ADC #1
        CLC
        ADC T0
        TAY
        LDA stepdir,Y
        LDY MT
        STA TDIR,Y
        LDA #0              ; off the old square
        STA GRID,X
        JSR drawcell
        LDX T2
        LDA GRID,X
        STA MPICK           ; what's on the new one
        LDY MT
        TXA
        STA TPOS,Y
        INY
        TYA
        STA GRID,X
        JSR drawcell
        LDX #<t_step
        LDY #>t_step
        JSR play
        LDA #7
        JSR delay
        LDA MPICK
        BEQ @next
        CMP #COIN
        BNE @tool
        LDX TURN            ; a coin
        LDA CASH,X
        CLC
        ADC #BOUNTY
        CMP #250
        BCS @kept
        STA CASH,X
@kept:  LDX #<m_coin
        LDY #>m_coin
        JSR msgt
        LDX #<t_coin
        LDY #>t_coin
        BNE @got
@tool:  LDX MT              ; a spanner
        LDA #3
        STA THP,X
        LDX T2
        JSR drawcell
        LDX #<m_tool
        LDY #>m_tool
        JSR msgt
        LDX #<t_tool
        LDY #>t_tool
@got:   JSR play
        JSR panel
        LDA MPICK
        JSR respawn
        LDA #8
        JSR delay
@next:  INC MK
        LDA MK
        CMP MN
        BEQ @done
        JMP @step
@done:  SEC
        LDA MOVES
        SBC MN
        STA MOVES
        LDX #CELLS-1
@clean: LDA FLAGS,X
        AND #$FF-ONPATH
        STA FLAGS,X
        DEX
        BNE @clean
        RTS

; RESPAWN: what was picked up (A) turns up on a free square, not one of the drive's.
respawn:
        STA T2
        LDY #0              ; how many are free
        LDX #CELLS-1
@count: LDA GRID,X
        ORA FLAGS,X
        BNE @c
        INY
@c:     DEX
        BNE @count
        STY T0
        TYA
        BEQ @none
@roll:  JSR RND
        AND #$7F
        CMP T0
        BCS @roll
        TAY                 ; the Yth of them
        LDX #0
@find:  INX
        LDA GRID,X
        ORA FLAGS,X
        BNE @find
        DEY
        BPL @find
@put:   LDA T2
        STA GRID,X
        JMP drawcell
@none:  RTS

; DOSHOOT: tank X fires at tank Y. In range and with a clear line: the caller knows.
doshoot:
        STX ST
        STY SG
        LDA TPOS,Y
        STA SB
        TAY
        LDA TPOS,X
        TAX
        SEC
        LDA PX,Y
        SBC PX,X
        STA SDX
        SEC
        LDA PY,Y
        SBC PY,X
        STA SDY
        CLC
        ADC #3
        TAY
        LDA mul7,Y
        CLC
        ADC SDX
        CLC
        ADC #3
        TAY
        LDA SHOTDIR,Y       ; the gun turns to its target
        LDY ST
        STA TDIR,Y
        JSR drawcell
        LDA #5
        JSR delay
        LDA PX,X            ; the shell leaves from the middle of the gun's square
        ASL A
        ASL A
        ASL A
        ASL A
        ADC #15
        STA SHX
        LDA PY,X
        ASL A
        ASL A
        ASL A
        ASL A
        ADC #11
        STA SHY
        ASL SDX             ; and goes an eighth of the way a step
        ASL SDY
        LDX #<t_fire
        LDY #>t_fire
        JSR play
        LDA #7
        STA SN
@fly:   CLC
        LDA SHX
        ADC SDX
        STA SHX
        CLC
        LDA SHY
        ADC SDY
        STA SHY
        JSR shell
        LDA #2
        JSR delay
        JSR shell
        DEC SN
        BNE @fly
        LDA #0
        STA SPEAKER
        STA SNDT
        LDX SG              ; a hit
        SEC
        LDA THP,X
        SBC #1
        STA THP,X
        DEC MOVES
        LDA #4
        STA SN
@flash: LDX SB
        LDA FLAGS,X
        EOR #TARGET
        STA FLAGS,X
        JSR drawcell
        LDA #3
        JSR hiss
        DEC SN
        BNE @flash
        LDX SG
        LDA THP,X
        BEQ @dead
        LDX #<m_hit
        LDY #>m_hit
        JMP msgt
@dead:  LDX SB
        LDA #0
        STA GRID,X
        STA SN
@boom:  LDY SN
        LDA booms,Y
        LDX SB
        JSR drawspr
        LDA #6
        JSR hiss
        INC SN
        LDA SN
        CMP #3
        BNE @boom
        LDX SB
        JSR drawcell
        LDX #<m_dead
        LDY #>m_dead
        JSR msgt
        LDX SG
        LDA TTEAM,X
        JSR count
        BNE @left
        LDX TURN            ; that was the last of them
        INX
        STX WINNER
@left:  RTS

; DOBUY: a new tank for the side whose turn it is, on square X. Returns its number in Y.
dobuy:  LDY TURN
        SEC
        LDA CASH,Y
        SBC #PRICE
        STA CASH,Y
        DEC MOVES
        JSR spawn
        STY T3
        JSR drawcell
        LDX #<m_buy
        LDY #>m_buy
        JSR msgt
        LDX #<t_buy
        LDY #>t_buy
        JSR play
        LDA #12
        JSR delay
        LDY T3
        RTS

; SPAWN: a tank of side Y on square X, three hits of armour, facing the other side.
; Returns its number in Y; X is kept. There must be room: see FREESLOT.
spawn:  STY T0
        JSR freeslot
        LDA T0
        STA TTEAM,Y
        ASL A
        ASL A
        STA TDIR,Y          ; east for you, west for the enemy
        LDA #3
        STA THP,Y
        TXA
        STA TPOS,Y
        INY
        TYA
        STA GRID,X
        DEY
        RTS

; FREESLOT: Y = a tank number not in use, or the carry set if there's none.
freeslot:
        LDY #0
@look:  LDA THP,Y
        BEQ @free
        INY
        CPY #MAXT
        BNE @look
        RTS                 ; the CPY left the carry set
@free:  CLC
        RTS

; COUNT: A = how many tanks side A has. Z set if none.
count:  STA T0
        LDY #0
        LDX #MAXT-1
@each:  LDA THP,X
        BEQ @no
        LDA TTEAM,X
        CMP T0
        BNE @no
        INY
@no:    DEX
        BPL @each
        TYA
        RTS

; ---------------------------------------------------------------- reach and range

; BFST: the squares tank X can drive to with the moves left: BFS from its square.
bfst:   LDA TPOS,X
        TAX
        LDA MOVES
        CMP #3
        BCC bfs
        LDA #3

; BFS: from square X, A steps at most, a step being to any of the eight squares round
; one, but not on to a tank, and not between two tanks standing corner to corner.
; Leaves the squares in the order found in QP (QP+0 is X itself, QN how many), each
; one's steps in DIST and the square before it in PARENT.
bfs:    STA BMAX
        STX QP
        LDX #CELLS-1
        LDA #$FF
@clear: STA DIST,X
        DEX
        BNE @clear
        LDX QP
        LDA #0
        STA DIST,X
        STA QH
        LDA #1
        STA QN
@loop:  LDX QH
        CPX QN
        BEQ @done
        LDA QP,X
        STA BCUR
        INC QH
        TAX
        LDA DIST,X
        CMP BMAX
        BCS @loop           ; as far as it goes
        ADC #1
        STA BNEW
        LDY #0
@nb:    STY BK
        LDA BCUR
        CLC
        ADC around,Y
        TAX
        LDA GRID,X
        BEQ @open
        BPL @skip           ; a tank
        CMP #WALL
        BEQ @skip
@open:  LDA DIST,X
        BPL @skip           ; been there
        CPY #4
        BCC @take
        STX BN              ; a corner: is there a way through?
        LDA BCUR
        CLC
        ADC beside-4,Y
        TAX
        LDA GRID,X
        BEQ @thru
        BMI @thru
        LDA BCUR
        CLC
        ADC above-4,Y
        TAX
        LDA GRID,X
        BEQ @thru
        BPL @skip
@thru:  LDX BN
@take:  LDA BNEW
        STA DIST,X
        LDA BCUR
        STA PARENT,X
        TXA
        LDX QN
        STA QP,X
        INC QN
@skip:  LDY BK
        INY
        CPY #8
        BNE @nb
        BEQ @loop
@done:  RTS

; CANSHOOT: the carry set if a tank on square X could hit one on square Y: within three
; squares each way, and no tank on the line between. X is kept. It works both ways
; round, so it also says whether Y could hit X.
canshoot:
        SEC
        LDA PX,Y
        SBC PX,X
        CLC
        ADC #3
        CMP #7
        BCS @no
        STA T0
        SEC
        LDA PY,Y
        SBC PY,X
        CLC
        ADC #3
        CMP #7
        BCS @no
        TAY
        LDA mul7,Y
        CLC
        ADC T0
        TAY
        STX T0
        LDA LOSIX,Y
        TAY
@next:  LDA LOSLIST,Y       ; each square that would block it
        BEQ @yes
        CLC
        ADC T0
        TAX
        LDA GRID,X
        BEQ @clear
        BPL @block
@clear: INY
        BNE @next
@yes:   LDX T0
        SEC
        RTS
@block: LDX T0
@no:    CLC
        RTS

; CELLD2: A = the distance, squared, from square X to (MX, MY). Y is kept.
celld2: SEC
        LDA PX,X
        SBC MX
        BCS @a
        EOR #$FF
        ADC #1
@a:     STX T5
        TAX
        LDA squares,X
        LDX T5
        STA T5
        SEC
        LDA PY,X
        SBC MY
        BCS @b
        EOR #$FF
        ADC #1
@b:     TAX
        LDA squares,X
        CLC
        ADC T5
        RTS

; MIND2: A = the distance, squared, from square X to the nearest tank of side MTEAM;
; 255 if it has none.
mind2:  LDA PX,X
        STA MX
        LDA PY,X
        STA MY
        LDA #255
        STA MBEST
        LDY #MAXT-1
@each:  LDA THP,Y
        BEQ @no
        LDA TTEAM,Y
        CMP MTEAM
        BNE @no
        LDX TPOS,Y
        JSR celld2
        CMP MBEST
        BCS @no
        STA MBEST
@no:    DEY
        BPL @each
        LDA MBEST
        RTS

; DEPLOY: X = the best free square in side A's three home columns for a new tank, or 0
; if they're full (DBEST too). For you, the one nearest an enemy; for the enemy, the one
; whose nearest tank of yours is closest to four squares off. DBM is how far out it is.
deploy: STA DTEAM
        EOR #1
        STA MTEAM
        LDA #0
        STA DBEST
        LDA #$FF
        STA DBM
        LDA DTEAM
        BEQ @west
        LDA #9
@west:  CLC
        ADC #W+1
        STA DCOL
        LDA #3
        STA DI
@col:   LDA DCOL
        STA DP
        LDA #10
        STA DJ
@row:   LDX DP
        LDA GRID,X
        BNE @next
        JSR mind2
        LDX DTEAM
        BEQ @cmp
        TAX
        LDA SQRT16,X
        SEC
        SBC #64
        BCS @cmp
        EOR #$FF
        ADC #1
@cmp:   CMP DBM
        BCS @next
        STA DBM
        LDA DP
        STA DBEST
@next:  CLC
        LDA DP
        ADC #W
        STA DP
        DEC DJ
        BNE @row
        INC DCOL
        DEC DI
        BNE @col
        LDX DBEST
        RTS

; ---------------------------------------------------------------- the marks

; CLRHL: take the marks off the board, and the frame off the picked tank.
clrhl:  LDX #CELLS-1
@each:  LDA FLAGS,X
        BEQ @no
        LDA #0
        STA FLAGS,X
        JSR drawcell
@no:    DEX
        BNE @each
        LDX SELP
        BEQ @none
        LDA #0
        STA SELP
        JSR drawcell
@none:  RTS

; SETHL: mark what the picked tank can do: the squares it can drive to, the tanks it
; can hit. Nothing, if no tank is picked.
sethl:  JSR clrhl
        LDX SELT
        BMI @none
        LDA TPOS,X
        STA SELP
        LDA MOVES
        BEQ @frame
        JSR bfst
        LDA #1
        STA MI
@reach: LDX MI
        CPX QN
        BCS @aim
        LDA QP,X
        TAX
        LDA #REACH
        STA FLAGS,X
        JSR drawcell
        INC MI
        BNE @reach
@aim:   LDA #MAXT-1
        STA EI
@each:  LDY EI
        LDA THP,Y
        BEQ @no
        LDA TTEAM,Y
        BEQ @no
        LDX SELP
        LDA TPOS,Y
        TAY
        STY T3
        JSR canshoot
        BCC @no
        LDX T3
        LDA #TARGET
        STA FLAGS,X
        JSR drawcell
@no:    DEC EI
        BPL @each
@frame: LDX SELP
        JMP drawcell
@none:  RTS

; ---------------------------------------------------------------- the enemy thinks

; THINK: the best thing the enemy can do with a move, in BTYPE (0: nothing), BTANK
; and BARG.
think:  LDA #0
        STA BTYPE
        STA MTEAM           ; distances are to your tanks
        JSR count
        STA NHUM
        LDA #1
        JSR count
        STA NAI
        LDA #0
        STA AIT
@tank:  LDX AIT
        LDA THP,X
        BEQ @next
        LDA TTEAM,X
        BEQ @next
        JSR evaltank
@next:  INC AIT
        LDA AIT
        CMP #MAXT
        BNE @tank
        ; a new tank? Worth more the fewer it has.
        LDA CASH+1
        CMP #PRICE
        BCC @done
        JSR freeslot
        BCS @done
        LDA #1
        JSR deploy
        TXA
        BEQ @done
        LDA #<8400
        STA SC
        LDA #>8400
        STA SC+1
        LDA #5
        SEC
        SBC NAI
        BCC @many
        BEQ @many
        TAY
@few:   LDA #100
        JSR sca
        DEY
        BNE @few
@many:  LDA DBM
        JSR scs
        LDA #3
        LDX DBEST
        JSR cand
@done:  RTS

; Every drive and every shot tank AIT has.
evaltank:
        LDA TPOS,X
        STA AIP
        LDA THP,X
        STA AIH
        LDA #0              ; which of yours it can hit from where it stands
        STA AIR
        STA EI
@see:   LDY EI
        LDA THP,Y
        BEQ @blind
        LDA TTEAM,Y
        BNE @blind
        LDX AIP
        LDA TPOS,Y
        TAY
        JSR canshoot
        BCC @blind
        LDX AIR
        LDA EI
        STA SHL,X
        INC AIR
@blind: INC EI
        LDA EI
        CMP #MAXT
        BNE @see
        ; what every drive starts from: 18 points, closing on your nearest tank at 8 a
        ; square, and leaving a square where it can be hit
        LDA #<8072
        STA SC
        LDA #>8072
        STA SC+1
        LDX AIP
        JSR mind2
        TAX
        LDA SQRT16,X
        JSR sca
        JSR sca
        LDY AIR
        BEQ @based
@danger:
        LDA #48
        LDX AIH
        CPX #1
        BNE @sound
        LDA #160
@sound: JSR sca
        DEY
        BNE @danger
@based: LDA SC
        STA TBASE
        LDA SC+1
        STA TBASE+1
        LDX AIT
        JSR bfst
        LDA #1
        STA MI
@drive: LDX MI
        CPX QN
        BCS @shots
        LDA QP,X
        STA AID
        JSR evalmove
        INC MI
        BNE @drive
@shots: LDA #0              ; a shot: 100 points, more at a tank already hit, most at
        STA EI              ; one it finishes; and the battle if that's the last
@shot:  LDX EI
        CPX AIR
        BCS @done
        LDY SHL,X
        LDX THP,Y
        LDA shotlo-1,X
        STA SC
        LDA shothi-1,X
        STA SC+1
        CPX #1
        BNE @rated
        LDA NHUM
        CMP #1
        BNE @rated
        LDA SC+1
        CLC
        ADC #>20000
        STA SC+1
@rated: TYA
        TAX
        LDA #2
        JSR cand
        INC EI
        BNE @shot
@done:  RTS

; A drive to square AID.
evalmove:
        LDA TBASE
        STA SC
        LDA TBASE+1
        STA SC+1
        LDA #0              ; what it would pick up on the way
        STA GOTM
        STA GOTT
        LDX AID
@way:   CPX AIP
        BEQ @there
        LDA GRID,X
        CMP #COIN
        BNE @notm
        STA GOTM
@notm:  CMP #TOOL
        BNE @nott
        STA GOTT
@nott:  LDA PARENT,X
        TAX
        BNE @way
@there: LDX AID
        LDY DIST,X
        STY STEPS
@cost:  DEY                 ; 12 points a square after the first
        BEQ @paid
        LDA #48
        JSR scs
        JMP @cost
@paid:  LDX AID             ; put the tank there, to see
        LDA GRID,X
        STA SAVEG
        LDY AIT
        INY
        TYA
        STA GRID,X
        LDX AIP
        LDA #0
        STA GRID,X
        LDX AID
        JSR mind2
        STA TD2
        TAX
        LDA SQRT16,X
        JSR scs
        JSR scs
        LDA TD2
        CMP #3              ; next to one of yours: too close
        BCS @room
        LDA #60
        JSR scs
@room:  LDA GOTM
        BEQ @nocoin
        LDA #130            ; a coin: 65 points,
        JSR sca
        JSR sca
        LDA MOVES           ; 25 more if it can buy a tank with it at once
        CMP STEPS
        BEQ @nocoin
        LDA CASH+1
        CMP #PRICE-BOUNTY
        BCC @nocoin
        LDA #100
        JSR sca
@nocoin:
        LDA AIH
        STA HPA
        LDA GOTT
        BEQ @notool
        LDA #80             ; a spanner: 20 points, and 58 for each hit it mends
        JSR sca
@mend:  LDA HPA
        CMP #3
        BEQ @notool
        LDA #232
        JSR sca
        INC HPA
        BNE @mend
@notool:
        LDA #0              ; which of yours it could hit from there, and they it
        STA HCNT
        STA MAXD
        STA EI
@see:   LDY EI
        LDA THP,Y
        BEQ @blind
        LDA TTEAM,Y
        BNE @blind
        LDX AID
        LDA TPOS,Y
        TAY
        JSR canshoot
        BCC @blind
        INC HCNT
        LDY EI
        LDA #3
        SEC
        SBC THP,Y
        CMP MAXD
        BCC @blind
        STA MAXD
@blind: INC EI
        LDA EI
        CMP #MAXT
        BNE @see
        LDY HCNT
        BEQ @safe
        LDA #92             ; a target: 23 points, and 8 for each hit it has taken
        JSR sca
        LDX MAXD
        BEQ @risk
@hurt:  LDA #32
        JSR sca
        DEX
        BNE @hurt
@risk:  LDX HPA             ; and for each that can hit back: 12 points off, 28 with
        LDA risklo-1,X      ; one hit left to take, 80 with none
        JSR scs
        LDA HPA
        CMP #1
        BNE @risk1
        LDA #160
        JSR scs
@risk1: DEY
        BNE @risk
@safe:  LDA #0              ; its own side close by: 4 points each, for two
        STA NEAR
        LDX AID
        LDA PX,X
        STA MX
        LDA PY,X
        STA MY
        LDY #MAXT-1
@pals:  CPY AIT
        BEQ @notpal
        LDA THP,Y
        BEQ @notpal
        LDA TTEAM,Y
        BEQ @notpal
        LDX TPOS,Y
        JSR celld2
        CMP #9
        BCS @notpal
        LDA NEAR
        CMP #2
        BEQ @notpal
        INC NEAR
        LDA #16
        JSR sca
@notpal:
        DEY
        BPL @pals
        LDX AID             ; and back
        LDA SAVEG
        STA GRID,X
        LDX AIP
        LDY AIT
        INY
        TYA
        STA GRID,X
        LDA #1
        LDX AID

; CAND: something the enemy could do (A what, X to which square or at which tank),
; worth SC. Kept if it beats the best so far.
cand:   LDY BTYPE
        BEQ @take
        LDY SC+1
        CPY BSC+1
        BCC @no
        BNE @take
        LDY SC
        CPY BSC
        BCC @no
        BEQ @no
@take:  STA BTYPE
        STX BARG
        LDA AIT
        STA BTANK
        LDA SC
        STA BSC
        LDA SC+1
        STA BSC+1
@no:    RTS

; SCA, SCS: add A to the score, take A from it. X and Y are kept, and A.
sca:    PHA
        CLC
        ADC SC
        STA SC
        BCC @done
        INC SC+1
@done:  PLA
        RTS
scs:    PHA
        STA T5
        SEC
        LDA SC
        SBC T5
        STA SC
        BCS @done
        DEC SC+1
@done:  PLA
        RTS

; ---------------------------------------------------------------- drawing

; DRAWCELL: redraw square X, from what's on it and the marks over it. X is kept.
drawcell:
        STX DCP
        LDA GRID,X
        BEQ @empty
        BMI @thing
        TAY                 ; a tank: by its side and the way it faces
        DEY
        LDA TTEAM,Y
        ASL A
        ASL A
        ASL A
        ORA TDIR,Y
        TAX
        LDA tanklo,X
        STA SRC
        LDA tankhi,X
        STA SRC+1
        JSR fetch
        LDX THP,Y           ; and its armour, three bars under it
        LDA pips0,X
        STA CB+28
        LDA pips1,X
        STA CB+29
        JMP @marks
@empty: LDX #31
@blank: STA CB,X
        DEX
        BPL @blank
        BMI @marks
@thing: AND #1
        TAX
        LDA thinglo,X
        JSR sprite
@marks: LDA CB              ; a dot at every square's corner
        ORA #$80
        STA CB
        LDX DCP
        LDA FLAGS,X
        LSR A
        BCC @aimed
        PHA
        LDX #31             ; in reach: a dotted ring
@ring:  LDA CB,X
        ORA sp_reach,X
        STA CB,X
        DEX
        BPL @ring
        PLA
@aimed: LSR A
        BCC @picked
        LDX #31             ; a target: in reverse
@rev:   LDA CB,X
        EOR #$FF
        STA CB,X
        DEX
        BPL @rev
@picked:
        LDX DCP
        CPX SELP
        BNE @cursor
        LDX #31             ; the picked tank: a frame
@frame: LDA CB,X
        ORA sp_ring,X
        STA CB,X
        DEX
        BPL @frame
@cursor:
        LDX DCP
        CPX CURP
        BNE blit
        LDA CURON
        BEQ blit
        LDX #31             ; the cursor: its corners, flipped
@curs:  LDA CB,X
        EOR sp_curs,X
        STA CB,X
        DEX
        BPL @curs

; put CB on the bitmap at square DCP
blit:   LDX DCP
        LDY PY,X
        LDA PX,X
        ASL A
        SEC                 ; a byte in from the edge
        ADC cellylo,Y
        STA PTR
        LDA cellyhi,Y
        ADC #0
        STA PTR+1
        LDX #0
@row:   LDY #0
        LDA CB,X
        STA (PTR),Y
        INY
        LDA CB+1,X
        STA (PTR),Y
        CLC
        LDA PTR
        ADC #40
        STA PTR
        BCC @same
        INC PTR+1
@same:  INX
        INX
        CPX #32
        BNE @row
        LDX DCP
        RTS

; DRAWSPR: sprite A (the low byte of its address: they're all in one page) alone on
; square X.
drawspr:
        STX DCP
        JSR sprite
        JMP blit

sprite: STA SRC
        LDA #>things
        STA SRC+1
fetch:  STY SY
        LDY #31
@copy:  LDA (SRC),Y
        STA CB,Y
        DEY
        BPL @copy
        LDY SY
        RTS

; CURSHOW: the cursor lit on its square, at the start of a blink.
curshow:
        LDA #1
        STA CURON
        LDA #15
        STA BLINK
        LDX CURP
        JMP drawcell

; SHELL: flip a 3 x 3 shell at (SHX, SHY): once draws it, twice takes it away.
shell:  LDX SHY
        LDA SHX
        STA SHIFT_AMT
        LSR A
        LSR A
        LSR A
        CLC
        ADC YLO,X
        STA PTR
        LDA YHI,X
        ADC #0
        STA PTR+1
        LDX #3
        LDY #0
@row:   LDA #%11100000
        STA SHIFT_IN
        LDA SHIFT_OUT
        EOR (PTR),Y
        STA (PTR),Y
        LDA #0
        STA SHIFT_IN
        INY
        LDA SHIFT_OUT
        EOR (PTR),Y
        STA (PTR),Y
        TYA
        CLC
        ADC #39
        TAY
        DEX
        BNE @row
        RTS

; BMCHAR: character A on the bitmap at column TXC, text row TXR, from the character
; ROM; TXC moves on. X and Y are kept.
bmchar: STX SX
        STY SY
        STA GP
        LDA #0
        STA GP+1
        ASL GP
        ROL GP+1
        ASL GP
        ROL GP+1
        ASL GP
        ROL GP+1
        LDA GP+1
        ORA #>CHARROM
        STA GP+1
        LDA TXR
        ASL A
        ASL A
        ASL A
        TAX
        CLC
        LDA YLO,X
        ADC TXC
        STA PTR
        LDA YHI,X
        ADC #0
        STA PTR+1
        LDY #0
@row:   LDA (GP),Y
        EOR TXINV
        STA (PTR),Y         ; PTR goes down 39 as Y goes along 1: a line
        CLC
        LDA PTR
        ADC #39
        STA PTR
        BCC @same
        INC PTR+1
@same:  INY
        CPY #8
        BNE @row
        INC TXC
        LDX SX
        LDY SY
        RTS

; PTEXT: the string at X/Y on the bitmap: its column, its row, then the letters to a 0.
ptext:  STX SRC
        STY SRC+1
        LDY #0
        LDA (SRC),Y
        STA TXC
        INY
        LDA (SRC),Y
        STA TXR
pcont:  INY                 ; (and from here, the letters after SRC's Yth)
        LDA (SRC),Y
        BEQ @done
        JSR bmchar
        JMP pcont
@done:  RTS

; BMNUM: A in decimal on the bitmap, no leading zeros.
bmnum:  LDX #0              ; X: has a digit been printed?
        LDY #100
        JSR @digit
        LDY #10
        JSR @digit
        ORA #'0'
        JMP bmchar
@digit: STY T0
        LDY #'0'
@sub:   CMP T0
        BCC @out
        SBC T0
        INY
        BNE @sub
@out:   CPY #'0'
        BNE @print
        CPX #0
        BEQ @skip
@print: PHA
        TYA
        JSR bmchar
        PLA
        LDX #1
@skip:  RTS

; PADTO: spaces up to column A.
padto:  STA T0
@each:  LDA TXC
        CMP T0
        BCS @done
        LDA #' '
        JSR bmchar
        JMP @each
@done:  RTS

; PANEL: the numbers beside the board.
panel:  LDA #32
        STA TXC
        LDA #2
        STA TXR
        LDA ROUND
        JSR bmnum
        LDA WINNER
        BEQ @turn
        CLC
        ADC #1
        BNE @label
@turn:  LDA TURN
@label: ASL A               ; 0 your turn, 1 the enemy's, 2 you won, 3 you lost
        TAX
        LDY labels+1,X
        LDA labels,X
        TAX
        JSR ptext
        LDA #32             ; the moves left
        STA TXC
        INC TXR
        LDX #0
@moves: LDA #BALL
        CPX MOVES
        BCC @left
        LDA #RING
@left:  JSR bmchar
        INX
        CPX #5
        BNE @moves
        LDA #32             ; your money
        STA TXC
        LDA #7
        STA TXR
        LDA #'$'
        JSR bmchar
        LDA CASH
        PHA
        JSR bmnum
        PLA
        BEQ @broke
        LDX #<p_000
        LDY #>p_000
        JSR @str
@broke: LDA #40
        JSR padto
        LDA #10             ; and the tanks
        STA TXR
        LDA #0
        JSR @count
        INC TXR
        LDA #1
        JSR @count
        JMP info
@count: JSR count
        LDX #37
        STX TXC
        JSR bmnum
        LDA #40
        JMP padto
@str:   STX SRC             ; a string at the cursor
        STY SRC+1
        LDY #$FF
        JMP pcont

; INFO: what's under the cursor, in words.
info:   LDX CURP
        LDY #0              ; nothing
        LDA GRID,X
        BEQ @say
        BPL @tank
        AND #1
        CLC
        ADC #3              ; 3 a coin, 4 a spanner
        TAY
        BNE @say
@tank:  TAX
        LDY TTEAM-1,X
        INY                 ; 1 yours, 2 the enemy's
        LDA THP-1,X
        PHA
        JSR @say
        LDX #<p_armour
        LDY #>p_armour
        JSR ptext
        PLA
        STA T1
        LDX #0
@pips:  LDA #BALL
        CPX T1
        BCC @has
        LDA #RING
@has:   JSR bmchar
        INX
        CPX #3
        BNE @pips
        RTS
@say:   TYA
        ASL A
        TAX
        LDY infos+1,X
        LDA infos,X
        TAX
        JSR ptext
        LDX #<p_blank       ; and no armour, unless it's a tank
        LDY #>p_blank
        JMP ptext

; PICTURE: the whole screen, for a new battle.
picture:
        JSR mode
        LDX #39
@rows:  LDA #' '
        STA ROW22,X
        STA ROW23,X
        STA ROW24,X
        STA SCREEN+21*40,X
        DEX
        BPL @rows
        LDA #>BM            ; the bitmap, cleared
        STA PTR+1
        LDA #0
        STA PTR
        TAY
        LDX #26
@clear: STA (PTR),Y
        INY
        BNE @clear
        INC PTR+1
        DEX
        BNE @clear
@last:  STA (PTR),Y
        INY
        CPY #$40
        BNE @last
        LDX #3              ; a frame round the board, lines 3 to 164
@frame: LDA YLO,X
        STA PTR
        LDA YHI,X
        STA PTR+1
        LDY #0
        LDA #$01
        STA (PTR),Y
        LDY #25
        LDA #$80
        STA (PTR),Y
        CPX #3
        BEQ @edge
        CPX #164
        BNE @side
@edge:  DEY
        LDA #$FF
@line:  STA (PTR),Y
        DEY
        BNE @line
@side:  INX
        CPX #165
        BNE @frame
        LDX #CELLS-1        ; the squares
@cells: LDA GRID,X
        CMP #WALL
        BEQ @wall
        JSR drawcell
@wall:  DEX
        BNE @cells
        LDA #$FF            ; the panel: its name in reverse,
        STA TXINV
        LDX #<p_name
        LDY #>p_name
        JSR ptext
        LDA #0
        STA TXINV
        LDA #<p_fixed       ; and what doesn't change
        STA MP
        LDA #>p_fixed
        STA MP+1
@fixed: LDX MP
        LDY MP+1
        JSR ptext
        TYA                 ; PTEXT leaves Y at the string's 0
        SEC
        ADC MP
        STA MP
        BCC @same
        INC MP+1
@same:  LDY #0
        LDA (MP),Y
        BPL @fixed          ; a column of $FF ends them
        JMP panel

; MODE: the bitmap, with the last four text rows under it.
mode:   LDA #BMPAGE
        STA BITMAP
        LDA #4
        STA TEXTROWS
        LDA #MIXED
        STA VMODE
        RTS

; ---------------------------------------------------------------- messages

; MSG: the string at X/Y on a new message line. MSGT: the same, with whose turn it is
; in front: YOUR, or ENEMY.
msg:    STX MP
        STY MP+1
        JSR msgnew
        BEQ msgadd
msgt:   STX MP
        STY MP+1
        JSR msgnew
        LDX TURN
        LDA whose,X
        TAX
@who:   LDA s_your,X
        BEQ msgadd
        JSR msgchr
        INX
        BNE @who
msgadd: LDY #0
@each:  LDA (MP),Y
        BEQ @done
        JSR msgchr
        INY
        BNE @each
@done:  RTS
msgchr: STX SX
        LDX MSGX
        STA ROW24,X
        INC MSGX
        LDX SX
        RTS
msgnew: LDX #39             ; the lines move up one
@up:    LDA ROW23,X
        STA ROW22,X
        LDA ROW24,X
        STA ROW23,X
        LDA #' '
        STA ROW24,X
        DEX
        BPL @up
        LDA #0
        STA MSGX
        RTS

; ---------------------------------------------------------------- time and sound

; WAITFRAME: wait for the next frame, and step the tune.
waitframe:
        LDA FRAME
@wait:  CMP FRAME
        BEQ @wait
        LDA SNDT
        BEQ @quiet
        DEC SNDT
        BNE @quiet
        BEQ note
@quiet: RTS

; PLAY: play the tune at X/Y: for each note the timer's divisor and how many frames,
; and a length of 0 at the end.
play:   STX SND
        STY SND+1
note:   STY SY
        LDY #2
        LDA (SND),Y
        STA SNDT
        BEQ @end
        LDY #0
        LDA (SND),Y
        STA TIMER_LO
        INY
        LDA (SND),Y
        STA TIMER_HI
        LDA #%11            ; the timer to the speaker
        STA SPEAKER
        CLC
        LDA SND
        ADC #3
        STA SND
        BCC @same
        INC SND+1
@same:  LDY SY
        RTS
@end:   STA SPEAKER
        LDY SY
        RTS

; DELAY: wait A frames.
delay:  STA T1
@each:  JSR waitframe
        DEC T1
        BNE @each
        RTS

; HISS: A frames of noise, the speaker flipped by hand.
hiss:   STA T1
        LDA #0
        STA SPEAKER
        STA SNDT
@frame: LDA FRAME
        STA T0
@flip:  LDA NOISE
        BPL @rest
        STA BEEPER
@rest:  LDX #20
@pause: DEX
        BNE @pause
        LDA FRAME
        CMP T0
        BEQ @flip
        DEC T1
        BNE @frame
        LDA #0
        STA SPEAKER
        RTS

; ---------------------------------------------------------------- tables, made once

; TABLES: where each line of the bitmap starts, and each square's column and row.
tables: LDA #<BM
        STA PTR
        LDA #>BM
        STA PTR+1
        LDX #0
@line:  LDA PTR
        STA YLO,X
        CLC
        ADC #40
        STA PTR
        LDA PTR+1
        STA YHI,X
        ADC #0
        STA PTR+1
        INX
        CPX #168
        BNE @line
        LDX #0
        LDY #$FF            ; the wall's row is -1, its column -1 and 12
@row:   LDA #$FF
@col:   STA PX,X
        STY T0
        PHA
        LDA T0
        STA PY,X
        PLA
        INX
        CLC
        ADC #1
        CMP #W-1
        BNE @col
        INY
        CPX #CELLS
        BNE @row
        RTS

; ---------------------------------------------------------------- data

starts: .rept 5, i          ; where the ten tanks start: yours, the enemy's, in turn
        .byte [2*i+1]*W+2, [2*i+1]*W+11
        .endr
curstep:
        .byte -1, 1, -W, W  ; the cursor keys: left, right, up, down
around: .byte -1, 1, -W, W, -W-1, W-1, -W+1, W+1   ; the eight squares round one
beside: .byte -1, -1, 1, 1  ; for the last four, the corners: the square beside,
above:  .byte -W, W, -W, W  ; and the one above or below
stepdir:                    ; the way a tank faces after a step (dx, dy), at
        .byte 3, 2, 1       ; 3 * (dy + 1) + dx + 1: 0 east, 1 north-east, 2 north
        .byte 4, 0, 0       ; and so on round
        .byte 5, 6, 7
mul7:   .byte 0, 7, 14, 21, 28, 35, 42
squares:
        .rept 12, i
        .byte i*i
        .endr
SQRT16: .rept 203, i        ; 16 * the square root, to the nearest
        .byte [sqrt(i*1024)+1]/2
        .endr
pips0:  .byte 0, %00111000, %00111011, %00111011
pips1:  .byte 0, 0, %10000000, %10111000
cellylo:
        .rept 10, i
        .byte <[BM+[4+16*i]*40]
        .endr
cellyhi:
        .rept 10, i
        .byte >[BM+[4+16*i]*40]
        .endr
tanklo: .rept 16, i
        .byte <[tanks+i*32]
        .endr
tankhi: .rept 16, i
        .byte >[tanks+i*32]
        .endr
thinglo:
        .byte <sp_money, <sp_tool
booms:  .byte <sp_ex1, <sp_ex2, <sp_ex3
shotlo: .byte <9100, <8524, <8448       ; a shot's score, by the target's armour
shothi: .byte >9100, >8524, >8448
risklo: .byte 160, 112, 48              ; what being in range costs, by the tank's own
                                        ; (with one hit left, 160 twice: 320)
whose:  .byte 0, s_enemy-s_your
s_your: .asciiz "YOUR "
s_enemy:
        .asciiz "ENEMY "
labels: .word p_yours, p_theirs, p_won, p_lost
infos:  .word p_none, p_mine, p_foe, p_coin, p_tool

; the tunes: the divisor, the frames
t_step: .word 9000
        .byte 2, 0, 0, 0
t_pick: .word 1500
        .byte 2, 0, 0, 0
t_no:   .word 12000
        .byte 5, 0, 0, 0
t_fire: .word 900
        .byte 2
        .word 1300
        .byte 2
        .word 1900
        .byte 3
        .word 2800
        .byte 3
        .word 4000
        .byte 4, 0, 0, 0
t_coin: .word 1517
        .byte 3
        .word 1136
        .byte 3
        .word 758
        .byte 5, 0, 0, 0
t_tool: .word 2025
        .byte 3
        .word 1517
        .byte 3
        .word 2025
        .byte 3
        .word 1517
        .byte 5, 0, 0, 0
t_buy:  .word 3034
        .byte 3
        .word 2273
        .byte 3
        .word 1517
        .byte 6, 0, 0, 0
t_won:  .word 1911
        .byte 6
        .word 1517
        .byte 6
        .word 1276
        .byte 6
        .word 956
        .byte 14, 0, 0, 0
t_lost: .word 2551
        .byte 8
        .word 3034
        .byte 8
        .word 3822
        .byte 8
        .word 5102
        .byte 16, 0, 0, 0

; the panel
p_name: .byte 26, 0
        .asciiz "    SALVO     "
p_fixed:
        .byte 26, 2
        .asciiz "ROUND"
        .byte 26, 5
        .asciiz "MOVES"
        .byte 26, 7
        .asciiz "CASH"
        .byte 26, 8
        .asciiz "TANK  $4,000"
        .byte 26, 10
        .asciiz "YOUR TANKS"
        .byte 26, 11
        .asciiz "ENEMY"
        .byte 26, 16
        .asciiz "ARROWS, SPACE:"
        .byte 26, 17
        .asciiz "PICK, GO, FIRE"
        .byte 26, 18
        .asciiz "N    NEXT TANK"
        .byte 26, 19
        .asciiz "B     BUY TANK"
        .byte 26, 20
        .asciiz "RETURN    DONE"
        .byte $FF
p_yours:
        .byte 26, 4
        .asciiz "YOUR TURN "
p_theirs:
        .byte 26, 4
        .asciiz "ENEMY TURN"
p_won:  .byte 26, 4
        .asciiz "YOU WON!  "
p_lost: .byte 26, 4
        .asciiz "YOU LOST. "
p_000:  .asciiz ",000"
p_none: .byte 26, 13
        .asciiz "           "
p_mine: .byte 26, 13
        .asciiz "YOUR TANK  "
p_foe:  .byte 26, 13
        .asciiz "ENEMY TANK "
p_coin: .byte 26, 13
        .asciiz "$2,000     "
p_tool: .byte 26, 13
        .asciiz "REPAIRS    "
p_armour:
        .byte 26, 14
        .asciiz "ARMOUR "
p_blank:
        .byte 26, 14
        .asciiz "          "

; the messages
m_start:
        .asciiz "DESTROY EVERY ENEMY TANK. YOUR MOVE."
m_yours:
        .asciiz "YOUR TURN."
m_nosel:
        .asciiz "PICK ONE OF YOUR TANKS FIRST."
m_noshot:
        .asciiz "NO CLEAR SHOT WITHIN THREE SQUARES."
m_far:  .asciiz "THAT SQUARE IS OUT OF REACH."
m_poor: .asciiz "A TANK COSTS $4,000."
m_full: .asciiz "THERE IS NO ROOM FOR ANOTHER TANK."
m_coin: .asciiz "TANK FOUND $2,000."
m_tool: .asciiz "TANK IS REPAIRED."
m_hit:  .asciiz "SHELL HITS."
m_dead: .asciiz "SHELL DESTROYS A TANK!"
m_buy:  .asciiz "NEW TANK ROLLS OUT."
m_won:  .asciiz "THE LAST ENEMY TANK IS GONE: YOU WON!"
m_lost: .asciiz "YOUR LAST TANK IS GONE: YOU LOST."
m_again:
        .asciiz "PRESS SPACE FOR ANOTHER BATTLE."

; the title page: 13 is a new line
title:  .byte 13, 13
        .text "                S A L V O"
        .byte 13, 13
        .text "       A BATTLE OF TANKS, IN TURNS"
        .byte 13, 13, 13
        .text "  FIVE TANKS A SIDE, AND FIVE MOVES A"
        .byte 13
        .text "  TURN, FOR ANY OF YOUR TANKS:"
        .byte 13, 13
        .text "  DRIVE  A MOVE A SQUARE, UP TO THREE"
        .byte 13
        .text "         SQUARES AT A TIME"
        .byte 13
        .text "  FIRE   AT AN ENEMY WITHIN THREE"
        .byte 13
        .text "         SQUARES, WITH NO TANK IN THE"
        .byte 13
        .text "         WAY. THREE HITS DESTROY IT"
        .byte 13
        .text "  BUY    A NEW TANK: $4,000 AND A MOVE"
        .byte 13, 13
        .text "  DRIVE OVER A COIN FOR $2,000, AND"
        .byte 13
        .text "  OVER A SPANNER TO REPAIR A TANK."
        .byte 13, 13
        .text "  YOUR TANKS ARE THE SOLID ONES. THE"
        .byte 13
        .text "  SIDE WITH NO TANKS LEFT HAS LOST."
        .byte 13, 13, 13
        .text "           PRESS SPACE TO START"
        .byte 0


; The tanks, 16 x 16, a row in two bytes: yours solid, the enemy's hollow, each facing
; east, north-east, north and so on round, anticlockwise.
tanks:
tk_y_e:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00111111, %11000000
        .byte %00111111, %11000000
        .byte %00011111, %10000000
        .byte %00011111, %11000000
        .byte %00011001, %11111100
        .byte %00011001, %11111100
        .byte %00011111, %11000000
        .byte %00011111, %10000000
        .byte %00111111, %11000000
        .byte %00111111, %11000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_ne:
        .byte %00000000, %00000000
        .byte %00000000, %00001100
        .byte %00000011, %00011000
        .byte %00000111, %10110000
        .byte %00001111, %11100000
        .byte %00011111, %01100000
        .byte %00111111, %00111000
        .byte %00011111, %01111000
        .byte %00001111, %11111000
        .byte %00000111, %11110000
        .byte %00000011, %11100000
        .byte %00000001, %11000000
        .byte %00000000, %10000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_n:
        .byte %00000000, %00000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00011011, %11011000
        .byte %00011111, %11111000
        .byte %00011111, %11111000
        .byte %00011110, %01111000
        .byte %00011110, %01111000
        .byte %00011111, %11111000
        .byte %00011111, %11111000
        .byte %00011000, %00011000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_nw:
        .byte %00000000, %00000000
        .byte %00100000, %00000000
        .byte %00110001, %11000000
        .byte %00011001, %11100000
        .byte %00001111, %11110000
        .byte %00000110, %11111000
        .byte %00001100, %01111100
        .byte %00011111, %11111000
        .byte %00011111, %11110000
        .byte %00001111, %11100000
        .byte %00000111, %11000000
        .byte %00000011, %10000000
        .byte %00000001, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_w:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000011, %11111100
        .byte %00000011, %11111100
        .byte %00000001, %11111000
        .byte %00000011, %11111000
        .byte %00111111, %10011000
        .byte %00111111, %10011000
        .byte %00000011, %11111000
        .byte %00000001, %11111000
        .byte %00000011, %11111100
        .byte %00000011, %11111100
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_sw:
        .byte %00000000, %00000000
        .byte %00000001, %00000000
        .byte %00000011, %10000000
        .byte %00000111, %11000000
        .byte %00001111, %11100000
        .byte %00011111, %11110000
        .byte %00011110, %11111000
        .byte %00011100, %11111100
        .byte %00000110, %11111000
        .byte %00000111, %11110000
        .byte %00001101, %11100000
        .byte %00011000, %11000000
        .byte %00110000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_s:
        .byte %00000000, %00000000
        .byte %00011000, %00011000
        .byte %00011111, %11111000
        .byte %00011111, %11111000
        .byte %00011110, %01111000
        .byte %00011110, %01111000
        .byte %00011111, %11111000
        .byte %00011111, %11111000
        .byte %00011011, %11011000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_y_se:
        .byte %00000000, %00000000
        .byte %00000000, %10000000
        .byte %00000001, %11000000
        .byte %00000011, %11100000
        .byte %00000111, %11110000
        .byte %00001111, %11111000
        .byte %00011111, %11111000
        .byte %00111110, %00110000
        .byte %00011111, %01100000
        .byte %00001111, %11110000
        .byte %00000111, %10011000
        .byte %00000011, %10001100
        .byte %00000000, %00000100
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_e:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00111111, %11000000
        .byte %00100000, %01000000
        .byte %00011111, %10000000
        .byte %00010000, %11000000
        .byte %00010110, %11111100
        .byte %00010110, %11111100
        .byte %00010000, %11000000
        .byte %00011111, %10000000
        .byte %00100000, %01000000
        .byte %00111111, %11000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_ne:
        .byte %00000000, %00000000
        .byte %00000000, %00001100
        .byte %00000011, %00011000
        .byte %00000100, %10110000
        .byte %00001000, %01100000
        .byte %00010001, %10100000
        .byte %00100011, %10011000
        .byte %00010001, %00001000
        .byte %00001000, %00001000
        .byte %00000100, %00010000
        .byte %00000010, %00100000
        .byte %00000001, %01000000
        .byte %00000000, %10000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_n:
        .byte %00000000, %00000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00011011, %11011000
        .byte %00010111, %11101000
        .byte %00010100, %00101000
        .byte %00010101, %10101000
        .byte %00010101, %10101000
        .byte %00010100, %00101000
        .byte %00010111, %11101000
        .byte %00011000, %00011000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_nw:
        .byte %00000000, %00000000
        .byte %00100000, %00000000
        .byte %00110001, %11000000
        .byte %00011001, %00100000
        .byte %00001110, %00010000
        .byte %00000100, %00001000
        .byte %00001011, %00000100
        .byte %00010011, %10001000
        .byte %00010001, %00010000
        .byte %00001000, %00100000
        .byte %00000100, %01000000
        .byte %00000010, %10000000
        .byte %00000001, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_w:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000011, %11111100
        .byte %00000010, %00000100
        .byte %00000001, %11111000
        .byte %00000011, %00001000
        .byte %00111111, %01101000
        .byte %00111111, %01101000
        .byte %00000011, %00001000
        .byte %00000001, %11111000
        .byte %00000010, %00000100
        .byte %00000011, %11111100
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_sw:
        .byte %00000000, %00000000
        .byte %00000001, %00000000
        .byte %00000010, %10000000
        .byte %00000100, %01000000
        .byte %00001000, %00100000
        .byte %00010000, %00010000
        .byte %00010000, %10001000
        .byte %00011001, %11000100
        .byte %00000101, %10001000
        .byte %00000110, %00010000
        .byte %00001101, %00100000
        .byte %00011000, %11000000
        .byte %00110000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_s:
        .byte %00000000, %00000000
        .byte %00011000, %00011000
        .byte %00010111, %11101000
        .byte %00010100, %00101000
        .byte %00010101, %10101000
        .byte %00010101, %10101000
        .byte %00010100, %00101000
        .byte %00010111, %11101000
        .byte %00011011, %11011000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000001, %10000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
tk_f_se:
        .byte %00000000, %00000000
        .byte %00000000, %10000000
        .byte %00000001, %01000000
        .byte %00000010, %00100000
        .byte %00000100, %00010000
        .byte %00001000, %10001000
        .byte %00010001, %11001000
        .byte %00100000, %11010000
        .byte %00010000, %00100000
        .byte %00001000, %01110000
        .byte %00000100, %10011000
        .byte %00000011, %10001100
        .byte %00000000, %00000100
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
things:                     ; the rest; SPRITE finds the first five by their low bytes
sp_money:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000111, %11100000
        .byte %00001000, %00010000
        .byte %00010001, %10001000
        .byte %00100011, %11000100
        .byte %00100110, %10100100
        .byte %00100011, %10000100
        .byte %00100001, %11000100
        .byte %00100101, %01100100
        .byte %00100011, %11000100
        .byte %00010001, %10001000
        .byte %00001000, %00010000
        .byte %00000111, %11100000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
sp_tool:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00110000
        .byte %00000000, %01100000
        .byte %00000000, %11000100
        .byte %00000000, %11001100
        .byte %00000000, %11111100
        .byte %00000001, %11110000
        .byte %00000011, %10000000
        .byte %00000111, %00000000
        .byte %00001110, %00000000
        .byte %00011100, %00000000
        .byte %00111000, %00000000
        .byte %00110000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
sp_ex1:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000001, %00000000
        .byte %00000101, %10100000
        .byte %00000011, %11000000
        .byte %00000111, %11100000
        .byte %00000011, %11000000
        .byte %00000101, %10100000
        .byte %00000001, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
sp_ex2:
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00001000, %00010000
        .byte %00000101, %10100000
        .byte %00010011, %11001000
        .byte %00000111, %11100000
        .byte %00001110, %01110000
        .byte %00101100, %00110100
        .byte %00001100, %00110000
        .byte %00001110, %01110000
        .byte %00000111, %11100000
        .byte %00010011, %11001000
        .byte %00000101, %10100000
        .byte %00001000, %00010000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
sp_ex3:
        .byte %00000000, %00000000
        .byte %01000010, %00010000
        .byte %00010000, %00100010
        .byte %00000010, %10000000
        .byte %01001000, %00100000
        .byte %00000000, %00100100
        .byte %00010010, %00000000
        .byte %01000000, %00001000
        .byte %00000010, %00100010
        .byte %00100000, %00000000
        .byte %00000100, %01001000
        .byte %01000000, %00001000
        .byte %00001001, %00000000
        .byte %00100000, %00100010
        .byte %00000010, %00000000
        .byte %00000000, %00000000
sp_reach:
        .byte %00000000, %00000000
        .byte %01010101, %01010110
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01000000, %00000000
        .byte %00000000, %00000010
        .byte %01101010, %10101010
        .byte %00000000, %00000000
sp_ring:
        .byte %11111111, %11111111
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %10000000, %00000001
        .byte %11111111, %11111111
sp_curs:
        .byte %11111000, %00011111
        .byte %11111000, %00011111
        .byte %11000000, %00000011
        .byte %11000000, %00000011
        .byte %11000000, %00000011
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %00000000, %00000000
        .byte %11000000, %00000011
        .byte %11000000, %00000011
        .byte %11000000, %00000011
        .byte %11111000, %00011111
        .byte %11111000, %00011111
        .assert [>sp_money] == [>sp_ex3], "the sprites DRAWSPR draws must be in one page"
; Line of sight. LOSIX: for a shot (dx, dy), at (dy + 3) * 7 + dx + 3, where in LOSLIST its
; list starts: the cells in between that block it, as steps from the gun, 0 the end.
LOSIX:
        .byte 1, 4, 7, 10, 13, 16, 19
        .byte 22, 2, 25, 8, 28, 17, 31
        .byte 34, 37, 0, 0, 0, 40, 43
        .byte 46, 35, 0, 0, 0, 41, 49
        .byte 52, 55, 0, 0, 0, 58, 61
        .byte 64, 56, 67, 68, 70, 59, 73
        .byte 76, 79, 82, 85, 88, 91, 94
LOSLIST:
        .byte 0, -30, -15, 0, -29, -15, 0, -29, -14, 0, -28, -14
        .byte 0, -27, -14, 0, -27, -13, 0, -26, -13, 0, -16, -15
        .byte 0, -15, -14, 0, -14, -13, 0, -13, -12, 0, -16, -1
        .byte 0, -15, -1, 0, -13, 1, 0, -12, 1, 0, -2, -1
        .byte 0, 1, 2, 0, -1, 12, 0, -1, 13, 0, 1, 15
        .byte 0, 1, 16, 0, 12, 13, 0, 13, 14, 0, 14, 15
        .byte 0, 15, 16, 0, 13, 26, 0, 13, 27, 0, 14, 27
        .byte 0, 14, 28, 0, 14, 29, 0, 15, 29, 0, 15, 30
        .byte 0
; Which way a gun turns for a shot (dx, dy), by the same index.
SHOTDIR:
        .byte 3, 3, 2, 2, 2, 1, 1
        .byte 3, 3, 3, 2, 1, 1, 1
        .byte 4, 3, 3, 2, 1, 1, 0
        .byte 4, 4, 4, 0, 0, 0, 0
        .byte 4, 5, 5, 6, 7, 7, 0
        .byte 5, 5, 5, 6, 7, 7, 7
        .byte 5, 5, 6, 6, 6, 7, 7

; ---------------------------------------------------------------- memory, filled in
YLO:    .res 168        ; where each line of the bitmap starts
YHI:    .res 168
PY:     .res CELLS      ; a square's row, 0-9
TPOS:   .res MAXT       ; the tanks: the square each is on,
THP:    .res MAXT       ; its armour, 3 to 1 (0: no such tank),
TTEAM:  .res MAXT       ; its side, 0 yours and 1 the enemy's,
TDIR:   .res MAXT       ; and the way it faces, 0 east and on round to 7
QP:     .res 64         ; the search's squares, in the order found
PATH:   .res 4          ; a drive, square by square
SHL:    .res MAXT       ; your tanks that an enemy tank can hit
        .assert * <= BM, "the program runs into the bitmap"
