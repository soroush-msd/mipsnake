#
# CP1521 Assignment 1 -- Worm on a Plane!
#
# Base code by Jashank Jeremy and Wael Alghamdi
# Tweaked (severely) by John Shepherd
#
# Set your tabstop to 8 to make the formatting decent

# Requires:
#  - [no external symbols]

# Provides:
	.globl	wormCol
	.globl	wormRow
	.globl	grid
	.globl	randSeed

	.globl	main
	.globl	clearGrid
	.globl	drawGrid
	.globl	initWorm
	.globl	onGrid
	.globl	overlaps
	.globl	moveWorm
	.globl	addWormToGrid
	.globl	giveUp
	.globl	intValue
	.globl	delay
	.globl	seedRand
	.globl	randValue

	# Let me use $at, please.
	.set	noat

# The following notation is used to suggest places in
# the program, where you might like to add debugging code
#
# If you see e.g. putc('a'), replace by the three lines
# below, with each x replaced by 'a'
#
# print out a single character
# define putc(x)
# 	addi	$a0, $0, x
# 	addiu	$v0, $0, 11
# 	syscall
# 
# print out a word-sized int
# define putw(x)
# 	add 	$a0, $0, x
# 	addiu	$v0, $0, 1
# 	syscall

####################################
# .DATA
	.data

	.align 4
wormCol:	.space	40 * 4
	.align 4
wormRow:	.space	40 * 4
	.align 4
grid:		.space	20 * 40 * 1

randSeed:	.word	0

main__0:	.asciiz "Invalid Length (4..20)"
main__1:	.asciiz "Invalid # Moves (0..99)"
main__2:	.asciiz "Invalid Rand Seed (0..Big)"
main__3:	.asciiz "Iteration "
main__4:	.asciiz "Blocked!\n"

	# ANSI escape sequence for 'clear-screen'
main__clear:	.asciiz "\033[H\033[2J"
# main__clear:	.asciiz "__showpage__\n" # for debugging

giveUp__0:	.asciiz "Usage: "
giveUp__1:	.asciiz " Length #Moves Seed\n"

####################################
# .TEXT <main>
	.text
main:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4
# Uses: 	$a0, $a1, $v0, $s0, $s1, $s2, $s3, $s4
# Clobbers:	$a0, $a1

# Locals:
#	- `argc' in $s0
#	- `argv' in $s1
#	- `length' in $s2
#	- `ntimes' in $s3
#	- `i' in $s4

# Structure:
#	main
#	-> [prologue]
#	-> main_seed
#	  -> main_seed_t
#	  -> main_seed_end
#	-> main_seed_phi
#	-> main_i_init
#	-> main_i_cond
#	   -> main_i_step
#	-> main_i_end
#	-> [epilogue]
#	-> main_giveup_0
#	 | main_giveup_1
#	 | main_giveup_2
#	 | main_giveup_3
#	   -> main_giveup_common

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -28

	# save argc, argv
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (argc < 3) giveUp(argv[0],NULL);
	slti	$at, $s0, 4
	bne	$at, $0, main_giveup_0

	# length = intValue(argv[1]);
	addi	$a0, $s1, 4	# 1 * sizeof(word)
	lw	$a0, ($a0)	# (char *)$a0 = *(char **)$a0
	jal	intValue

	# if (length < 4 || length >= 40)
	#     giveUp(argv[0], "Invalid Length");
	# $at <- (length < 4) ? 1 : 0
	slti	$at, $v0, 4
	bne	$at, $0, main_giveup_1
	# $at <- (length < 40) ? 1 : 0
	slti	$at, $v0, 40
	beq	$at, $0, main_giveup_1
	# ... okay, save length
	add	$s2, $0, $v0

	# ntimes = intValue(argv[2]);
	addi	$a0, $s1, 8	# 2 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (ntimes < 0 || ntimes >= 100)
	#     giveUp(argv[0], "Invalid # Iterations");
	# $at <- (ntimes < 0) ? 1 : 0
	slti	$at, $v0, 0
	bne	$at, $0, main_giveup_2
	# $at <- (ntimes < 100) ? 1 : 0
	slti	$at, $v0, 100
	beq	$at, $0, main_giveup_2
	# ... okay, save ntimes
	add	$s3, $0, $v0

main_seed:
	# seed = intValue(argv[3]);
	add	$a0, $s1, 12	# 3 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (seed < 0) giveUp(argv[0], "Invalid Rand Seed");
	# $at <- (seed < 0) ? 1 : 0
	slt	$at, $v0, $0
	bne	$at, $0, main_giveup_3

main_seed_phi:
	add	$a0, $0, $v0
	jal	seedRand

	# start worm roughly in middle of grid

	# startCol: initial X-coord of head (X = column)
	# int startCol = 40/2 - length/2;
	addi	$s4, $0, 2
	addi	$a0, $0, 40
	div	$a0, $s4
	mflo	$a0
	# length/2
	div	$s2, $s4
	mflo	$s4
	# 40/2 - length/2
	sub	$a0, $a0, $s4

	# startRow: initial Y-coord of head (Y = row)
	# startRow = 20/2;
	addi	$s4, $0, 2
	addi	$a1, $0, 20
	div	$a1, $s4
	mflo	$a1

	# initWorm($a0=startCol, $a1=startRow, $a2=length)
	add	$a2, $0, $s2
	jal	initWorm

main_i_init:
	# int i = 0;
	add	$s4, $0, $0
main_i_cond:
	# i <= ntimes  ->  ntimes >= i  ->  !(ntimes < i)
	#   ->  $at <- (ntimes < i) ? 1 : 0
	slt	$at, $s3, $s4
	bne	$at, $0, main_i_end

	# clearGrid();
	jal	clearGrid

	# addWormToGrid($a0=length);
	add	$a0, $0, $s2
	jal	addWormToGrid

	# printf(CLEAR)
	la	$a0, main__clear
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("Iteration ")
	la	$a0, main__3
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("%d",i)
	add	$a0, $0, $s4
	addiu	$v0, $0, 1	# print_int
	syscall

	# putchar('\n')
	addi	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

	# drawGrid();
	jal	drawGrid

	# Debugging? print worm pos as (r1,c1) (r2,c2) ...

	# if (!moveWorm(length)) {...break}
	add	$a0, $0, $s2
	jal	moveWorm
	bne	$v0, $0, main_moveWorm_phi

	# printf("Blocked!\n")
	la	$a0, main__4
	addiu	$v0, $0, 4	# print_string
	syscall

	# break;
	j	main_i_end

main_moveWorm_phi:
	addi	$a0, $0, 1
	jal	delay

main_i_step:
	addi	$s4, $s4, 1
	j	main_i_cond
main_i_end:

	# exit (EXIT_SUCCESS)
	# ... let's return from main with `EXIT_SUCCESS' instead.
	addi	$v0, $0, 0	# EXIT_SUCCESS

main__post:
	# tear down stack frame
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

main_giveup_0:
	add	$a1, $0, $0	# NULL
	j	main_giveup_common
main_giveup_1:
	la	$a1, main__0	# "Invalid Length"
	j	main_giveup_common
main_giveup_2:
	la	$a1, main__1	# "Invalid # Iterations"
	j	main_giveup_common
main_giveup_3:
	la	$a1, main__2	# "Invalid Rand Seed"
	# fall through
main_giveup_common:
	# giveUp ($a0=argv[0], $a1)
	lw	$a0, ($s1)	# argv[0]
	jal	giveUp		# never returns

####################################
# clearGrid() ... set all grid[][] elements to '.'
# .TEXT <clearGrid>
	.text
clearGrid:

# Frame:	$fp, $ra, $s0, $s1
# Uses: 	$s0, $s1
# Clobbers:	

# Locals:
#	- `row' in $s0
#	- `col' in $s1

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16
	
        ### TODO: Your code goes here
        li      $s0, 20                         # NRows = 20
        li      $s1, 40                         # NCols = 40
        li      $t0, 0                          # row = 0
    
for1_clearGrid:
        bge     $t0, $s0    end_clearGrid       # if(row >= NRows) goto end_clearGrid
        li      $t1, 0                          # col = 0

for2_clearGrid:
        bge     $t1, $s1    endfor2_clearGrid   # if(Col >= NCols) goto endfor1_clearGrid
        
        #offset = (NCols*row)+col
        mul     $t2, $t0, $s1                   # t2 = Ncols*row
        add     $t2, $t2, $t1                   # t2 = t0 + col 
        la      $t2, grid($t2)                  # t2 = &(grid + offset)
        
        li      $t3, '.'                        # t3 = '.'
        sb      $t3, ($t2)                      # grid[row][col] = '.'
        
        addi    $t1, $t1, 1                     # col++
        j       for2_clearGrid                  # jump to for2_clearGrid
    
endfor2_clearGrid:
        addi    $t0, $t0, 1                     # row++
        j       for1_clearGrid                  # jump to for1_clearGrid 


end_clearGrid:
	# tear down stack frame
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# drawGrid() ... display current grid[][] matrix
# .TEXT <drawGrid>
	.text
drawGrid:

# Frame:	$fp, $ra, $s0, $s1, $t1
# Uses: 	$s0, $s1
# Clobbers:	

# Locals:
#	- `row' in $s0
#	- `col' in $s1

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16
	
        ### TODO: Your code goes here
        li      $s0, 20                         # NRows = 20
        li      $s1, 40                         # NCols = 40
        li      $t0, 0                          # row = 0
    
for1_drawGrid:
        bge     $t0, $s0    end_drawGrid        # if(row >= NRows) goto end_drawGrid
        li      $t1, 0                          # col = 0

for2_drawGrid:
        bge     $t1, $s1    endfor2_drawGrid    # if(Col >= NCOLS) goto endfor1_drawGrid
        
        #offset = (NCols*row)+col
        mul     $t2, $t0, $s1                   # t2 = Ncols*row
        add     $t2, $t2, $t1                   # t2 = t0 + col 
        lb      $t2, grid($t2)                  # t2 = (grid + offset)
        
        move    $a0, $t2                        # printf("%c", grid[row][col])
        li      $v0, 11                             
        syscall                                 
        
        addi    $t1, $t1, 1                     # col++
        j       for2_drawGrid                   # jump to for2_drawGrid
    
endfor2_drawGrid:
        li      $a0, '\n'                       # printf("\n")
        li      $v0, 11
        syscall
        
        addi    $t0, $t0, 1                     # row++
        j       for1_drawGrid                   # jump to for1_drawGrid 
  
end_drawGrid:   
	# tear down stack frame
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# initWorm(col,row,len) ... set the wormCol[] and wormRow[]
#    arrays for a worm with head at (row,col) and body segements
#    on the same row and heading to the right (higher col values)
# .TEXT <initWorm>
	.text
initWorm:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2, $t0, $t1, $t2
# Clobbers:	$t0, $t1, $t2

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2
#	- `newCol' in $t0
#	- `nsegs' in $t1
#	- temporary in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8
	
        ### TODO: Your code goes here
        addi    $t0, $a0, 1                     # newCol = col + 1
        
        la      $t3, wormCol($0)                # t3 = &wormCol
        la      $t4, wormRow($0)                # t4 = &wormRow
        
        sw      $a0, ($t3)                      # wormCol[0] = col
        sw      $a1, ($t4)                      # wormRow[0] = row  
           
        li      $t1, 1                          # nsegs = 1
        
for_initWorm:
        bge     $t1, $a2    end_initWorm        # if(nsegs >= len) goto end_initWorm        

if_initWorm:
        li      $t5, 40                         # NCOLS = 40
        bne     $t0, $t5    initArrays          # if(newCol != NCOLS) goto initArrays
         
        j       end_initWorm                    # break

initArrays:
        li      $t2, 4                          #intsize = 4bytes
        mul     $t3, $t1, $t2                   #offset = nsegs * 4
        
        sw      $t0, wormCol($t3)               # wormCol + offset = newCol++
        addi    $t0, $t0, 1                     # newcol++ 
        
        sw      $a1, wormRow($t3)               # wormRow + offset = row
        addi    $t1, $t1, 1                     # nsegs++
        
        j       for_initWorm                    # jump to for_initWorm

end_initWorm:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# ongrid(col,row) ... checks whether (row,col)
#    is a valid coordinate for the grid[][] matrix
# .TEXT <onGrid>
	.text
onGrid:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $v0
# Clobbers:	$v0

# Locals:
#	- `col' in $a0
#	- `row' in $a1

# Code:

### TODO: complete this function

        # set up stack frame
        sw      $fp, -4($sp)
        sw      $ra, -8($sp)
        la      $fp, -4($sp)
        addiu   $sp, $sp, -8
    
        # code for function
        blt     $a0, $0    fail_onGrid          # fail if col < 0                          
        bge     $a0, 40    fail_onGrid          # fail if col >= NCOLS
        
        blt     $a1, $0    fail_onGrid          # fail if row < 0
        bge     $a1, 20    fail_onGrid          # fail if row >= NROWS
        
        li      $v0, 1                          # return success
        j       end_onGrid                      # jump to the end_onGrid
    
fail_onGrid:    
        li      $v0, 0                          # return failure
    
end_onGrid:
        # tear down stack frame
        lw      $ra, -4($fp)
        la      $sp, 4($fp)
        lw      $fp, ($fp)
        jr      $ra

####################################
# overlaps(r,c,len) ... checks whether (r,c) holds a body segment
# .TEXT <overlaps>
	.text
overlaps:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2
# Clobbers:	

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2

# Code:

### TODO: complete this function

        #set up stack frame
        sw      $fp, -4($sp)
	sw      $ra, -8($sp)
	sw      $s0, -12($sp)
	sw      $s1, -16($sp)
	sw      $s2, -20($sp)
	sw      $s3, -24($sp)
	sw      $s4, -28($sp)
	la      $fp, -4($sp)
	addiu   $sp, $sp, -28
    
        # code for function
        li      $s4, 0                          # i = 0
     
for_overlaps:
        bge     $s4, $a2    endfor_overlaps     # if(i >= len) goto endfor_overlaps   

if_overlaps:
        li      $s0, 4                          # intsize = 4bytes       
        mul     $s0, $s0, $s4                   # s0 = 4 * i
    
        lw      $s1, wormCol($s0)               # s1 = wormCol + offset
        lw      $s2, wormRow($s0)               # s2 = wormRow + offset
    
        bne     $s1, $a0 updateOffset           # if(wormCol != col) goto updateOffset
        bne     $s2, $a1 updateOffset           # if(wormRow != row) goto updateOffset
    
        li      $v0, 1                          # return 1
        j       end_overlaps                    # jump to end_overlaps
    
updateOffset:
        addi    $s4, $s4, 1                     # i++
        j       for_overlaps
    
endfor_overlaps:
        li      $v0, 0                          # return 0
        
end_overlaps:
    # tear down stack frame
	lw      $s4, -24($fp)
	lw      $s3, -20($fp)
	lw      $s2, -16($fp)
	lw      $s1, -12($fp)
	lw      $s0, -8($fp)
	lw      $ra, -4($fp)
	la      $sp, 4($fp)
	lw      $fp, ($fp)
	jr      $ra



####################################
# moveWorm() ... work out new location for head
#         and then move body segments to follow
# updates wormRow[] and wormCol[] arrays

# (col,row) coords of possible places for segments
# done as global data; putting on stack is too messy
	.data
	.align 4
possibleCol: .space 8 * 4	# sizeof(word)
possibleRow: .space 8 * 4	# sizeof(word)

# .TEXT <moveWorm>
	.text
moveWorm:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7
# Uses: 	$s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7, $t0, $t1, $t2, $t3
# Clobbers:	$t0, $t1, $t2, $t3

# Locals:
#	- `col' in $s0
#	- `row' in $s1
#	- `len' in $s2
#	- `dx' in $s3
#	- `dy' in $s4
#	- `n' in $s7
#	- `i' in $t0
#	- tmp in $t1
#	- tmp in $t2
#	- tmp in $t3
# 	- `&possibleCol[0]' in $s5
#	- `&possibleRow[0]' in $s6

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	sw	$s5, -32($sp)
	sw	$s6, -36($sp)
	sw	$s7, -40($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -40
	
        ### TODO: Your code goes here
        move    $s2, $a0                        # s2 = len
        li      $s7, 0                          # n = 0
        li      $s3, -1                         # dx = -1
        move    $t0, $s2                        # i = len
        addi    $t0, $t0, -1                    # i = i-1
    
for1_moveWorm: 
        bgt     $s3, 1    if2_moveWorm          # if(dx > 1) goto if2_moveWorm
        li      $s4, -1                         # dy = -1

for2_moveWorm:
        bgt     $s4, 1    endfor1_moveWorm      # if(dy > 1) goto
         
        lw      $s0, wormCol($0)                # col = wormCol[0]
        add     $s0, $s0, $s3                   # col = col + dx 
        
        lw      $s1, wormRow($0)                # row = wormRow[0]
        add     $s1, $s1, $s4                   # row = row + dy

if1_moveWorm:
        move    $a0, $s0                        # a0 = col
        move    $a1, $s1                        # a1 = row
        jal     onGrid                          # call onGrid function
        move    $t2, $v0                        # t2 = return onGrid value

        move    $a0, $s0                        # a0 = col
        move    $a1, $s1                        # a1 = row
        move    $a2, $s2                        # a2 = len
        jal     overlaps                        # call overlaps function
        move    $t3, $v0                        # t3 = return overlaps value
    
	    li      $t4, 1				            # t4 = 1
	    bne     $t2, $t4    endfor2_moveWorm	# if(t2!= 1)  goto endfor2_moveWorm
	    bne     $t3, $0	    endfor2_moveWorm	# if(t3 != 0) goto endfor2_moveWorm
	
        li      $t4, 4                          # intsize = 4bytes
        mul     $t4, $t4, $s7                   # offset = 4 * n
        
        sw      $s0, possibleCol($t4)           # possibleCol + offset = col
        sw      $s1, possibleRow($t4)           # possibleRow + offset = row
        
        addi    $s7, $s7, 1                     # n++
    
endfor2_moveWorm:
        addi    $s4, $s4, 1                     # dy++
        j       for2_moveWorm                   # jump back to for2_moveWorm

endfor1_moveWorm:
        addi    $s3, $s3, 1                     # dx++
        j       for1_moveWorm                   # jump back to for1_moveWorm
    
if2_moveWorm:
        bne     $s7, $0     for3_moveWorm       # if(n != 0) goto for3_moveWorm
        j       endif2_moveWorm                 # jump to endif2_moveWorm
    
for3_moveWorm:
        li      $t4, 4                          # t4 = 4
        ble     $t0, $0    possibleArray        # if(i <= 0) goto possibleArray
        
        move    $t5, $t0                        # t5 = i
        addi    $t5, $t5, -1                    # i = i - 1
        mul     $t5, $t5, $t4                   # t5 = i * 4
        
        lw      $t6, wormRow($t5)               # t6 = wormRow + offset
        mul     $t7, $t0, $t4                   # t7 = i * 4
        sw      $t6, wormRow($t7)               # wormRow[i] = wormRow[i-1]
        
        lw      $t6, wormCol($t5)               # t6 = wormCol + offset
        sw      $t6, wormCol($t7)               # wormCow[i] = wormCow[i-1]
        
        addi    $t0, $t0, -1                    # i--
        j       for3_moveWorm		 	        # jump back to for3_moveWorm

possibleArray:
        move    $a0, $s7                        # a0 = n
        jal     randValue                       # call the randValue function
        move    $t0, $v0                        # i = randValue(n)
         
        mul     $t4, $t4, $t0                   # t4 = 4 * i
        lw      $t5, possibleRow($t4)           # t5 = possibleRow + offset
        sw      $t5, wormRow($0)                # worm[0] = possibleRow[i]
        
        lw      $t5, possibleCol($t4)           # t5 = possibleCol + offset
        sw      $t5, wormCol($0)                # wormCol[0] = possibleCol[i]
        
        li      $v0, 1                          # return 1
        j       end_moveWorm                    # jump to end_moveWorm
    
endif2_moveWorm: 
        li      $v0, 0                          # return 0
  	
end_moveWorm:
	# tear down stack frame
	lw	$s7, -36($fp)
	lw	$s6, -32($fp)
	lw	$s5, -28($fp)
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra
	

####################################
# addWormTogrid(N) ... add N worm segments to grid[][] matrix
#    0'th segment is head, located at (wormRow[0],wormCol[0])
#    i'th segment located at (wormRow[i],wormCol[i]), for i > 0
# .TEXT <addWormToGrid>
	.text
addWormToGrid:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3
# Uses: 	$a0, $s0, $s1, $s2, $s3
# Clobbers:	

# Locals:
#	- `len' in $a0
#	- `&wormCol[i]' in $s0
#	- `&wormRow[i]' in $s1

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -24

        ### TODO: your code goes here
        lw      $t0, wormRow($0)                # row = wormRow[0]
        lw      $t1, wormCol($0)                # col = wormCol[0]
        
        #offset = (NCOLS*row)+col
        li      $t2, 40                         # NCOLS = 40
        mul     $t0, $t0, $t2                   # t0 = NCOLS * row
        add     $t0, $t0, $t1                   # t0 = t0 + col
        
        la      $t0, grid($t0)                  # t0 = &(grid+offset)
        li      $t1, '@'                        # t1 = '@'
        sb      $t1, ($t0)                      # grid[row][col] = '@'
        
        li      $t2, 1                          # i = 1 
        
for_addWormToGrid:
        bge     $t2, $a0  endfor_addWormToGrid  # if(i >= len) goto endfor_addWormToGrid 
        
        li      $t3, 4                          #intsize = 4 bytes
        mul     $t3, $t3, $t2                   #offset = i * 4
        
        la      $s1, wormRow($t3)               # s1 = &(wormRow + t3)
        la      $s0, wormCol($t3)               # s0 = &(wormCol + t3)
        lw      $t0, ($s1)                      # row = (wormRow + t3)
        lw      $t1, ($s0)                      # col = (wormCol + t3)
        
        li      $t3, 40                         # NCOLS = 40
        mul     $t0, $t0, $t3                   # t0 = row * NCOLS
        add     $t0, $t0, $t1                   # t0 = t0 + col
        la      $t0, grid($t0)                  # t0 = &(grid+offset)
        
        li      $t3, 'o'                        # t3 = 'o'
        sb      $t3, ($t0)                      # grid[row][col] = 'o'
        
        addi    $t2, $t2, 1                     # i++
        j       for_addWormToGrid               # jump to the beginning of the loop  

endfor_addWormToGrid:
	# tear down stack frame
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# giveUp(msg) ... print error message and exit
# .TEXT <giveUp>
	.text
giveUp:

# Frame:	frameless; divergent
# Uses: 	$a0, $a1
# Clobbers:	$s0, $s1

# Locals:
#	- `progName' in $a0/$s0
#	- `errmsg' in $a1/$s1

# Code:
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (errmsg != NULL) printf("%s\n",errmsg);
	beq	$s1, $0, giveUp_usage

	# puts $a0
	add	$a0, $0, $s1
	addiu	$v0, $0, 4	# print_string
	syscall

	# putchar '\n'
	add	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

giveUp_usage:
	# printf("Usage: %s #Segments #Moves Seed\n", progName);
	la	$a0, giveUp__0
	addiu	$v0, $0, 4	# print_string
	syscall

	add	$a0, $0, $s0
	addiu	$v0, $0, 4	# print_string
	syscall

	la	$a0, giveUp__1
	addiu	$v0, $0, 4	# print_string
	syscall

	# exit(EXIT_FAILURE);
	addi	$a0, $0, 1 # EXIT_FAILURE
	addiu	$v0, $0, 17	# exit2
	syscall
	# doesn't return

####################################
# intValue(str) ... convert string of digits to int value
# .TEXT <intValue>
	.text
intValue:

# Frame:	$fp, $ra
# Uses: 	$t0, $t1, $t2, $t3, $t4, $t5
# Clobbers:	$t0, $t1, $t2, $t3, $t4, $t5

# Locals:
#	- `s' in $t0
#	- `*s' in $t1
#	- `val' in $v0
#	- various temporaries in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# int val = 0;
	add	$v0, $0, $0

	# register various useful values
	addi	$t2, $0, 0x20 # ' '
	addi	$t3, $0, 0x30 # '0'
	addi	$t4, $0, 0x39 # '9'
	addi	$t5, $0, 10

	# for (char *s = str; *s != '\0'; s++) {
intValue_s_init:
	# char *s = str;
	add	$t0, $0, $a0
intValue_s_cond:
	# *s != '\0'


	lb	$t1, ($t0)
	beq	$t1, $0, intValue_s_end

	# if (*s == ' ') continue; # ignore spaces
	beq	$t1, $t2, intValue_s_step

	# if (*s < '0' || *s > '9') return -1;
	blt	$t1, $t3, intValue_isndigit
	bgt	$t1, $t4, intValue_isndigit

	# val = val * 10
	mult	$v0, $t5
	mflo	$v0

	# val = val + (*s - '0');
	sub	$t1, $t1, $t3
	add	$v0, $v0, $t1

intValue_s_step:
	# s = s + 1
	addi	$t0, $t0, 1	# sizeof(byte)
	j	intValue_s_cond
intValue_s_end:

intValue__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

intValue_isndigit:
	# return -1
	addi	$v0, $0, -1
	j	intValue__post

####################################
# delay(N) ... waste some time; larger N wastes more time
#                            makes the animation believable
# .TEXT <delay>
	.text
delay:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	

# Locals:
#	- `n' in $a0

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8
	
        ### TODO: your code goes here
        li      $t0, 3                          # x = 3
        li      $t1, 0                          # i = 0
    
for1_delay:
        bge     $t1, $a0,   end_delay           # if(i >= n) goto end_delay
        li      $t2, 0                          # j = 0
    
for2_delay:
        li      $t3, 1000                       # t3 = 1000
        bge     $t2, $t3    endfor1_delay       # if( j >= 40000) goto endfor1_delay
        
        li      $t4, 0                          # k = 0
    
for3_delay:
        li      $t5, 100                        # t5 = 100
        bge     $t4, $t5,   endfor2_delay       # if(k >= 1000) goto endfor2_delay
        
        li      $t6, 3                          # t6 = 3
        mul     $t0, $t0, $t6                   # x = x * 3
        
        addi    $t4, $t4, 1                     # k++
        j       for3_delay                      # jump to for3_delay
    
endfor2_delay:
        addi    $t2, $t2, 1                     # j++
        j       for2_delay                      # jump to for2_delay
       
endfor1_delay:
        addi    $t1, $t1, 1                     # i++
        j       for1_delay                      # jump to for1_delay
                                
end_delay:    
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# seedRand(Seed) ... seed the random number generator
# .TEXT <seedRand>
	.text
seedRand:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	[none]

# Locals:
#	- `seed' in $a0

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# randSeed <- $a0
	sw	$a0, randSeed

seedRand__post:

	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# randValue(n) ... generate random value in range 0..n-1
# .TEXT <randValue>
	.text
randValue:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	$t0, $t1

# Locals:	[none]
#	- `n' in $a0

# Structure:
#	rand
#	-> [prologue]
#       no intermediate control structures
#	-> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# $t0 <- randSeed
	lw	$t0, randSeed
	# $t1 <- 1103515245 (magic)
	li	$t1, 0x41c64e6d

	# $t0 <- randSeed * 1103515245
	mult	$t0, $t1
	mflo	$t0

	# $t0 <- $t0 + 12345 (more magic)
	addi	$t0, $t0, 0x3039

	# $t0 <- $t0 & RAND_MAX
	and	$t0, $t0, 0x7fffffff

	# randSeed <- $t0
	sw	$t0, randSeed

	# return (randSeed % n)
	div	$t0, $a0
	mfhi	$v0

rand__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

