
# This file contains my implementation of Dr Mario.
# Benjamin Gavriely
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

#playing field specifications
bottle_width: 
    .word 17
bottle_height:
    .word 21
bottle_start:
    .word 908
bottleneck_width:
    .word 4
bottleneck_height:
    .word 2
bottleneck_start:
    .word 676
starting_pill_top:
    .word 684

#Colors
redred:
    .word 0xff0000,0xff0000
yellowyellow: 
    .word 0xFFFF00,0xFFFF00
blueblue:
    .word 0x0000ff,0x0000ff
redyellow:
    .word 0xff0000,0xFFFF00
redblue:
    .word 0xff0000,0x0000ff
blueyellow:
    .word 0x0000ff,0xFFFF00
    
#sound effects (pitch, duration, instrument, volume)
drop_sound:
    .word 40, 10, 13, 100
clear_line_sound:
    .word 70, 50, 35, 100
game_over_sound:
    .word 30, 3000, 13, 100
win_sound:
    .word 80, 5000, 13, 100
##############################################################################
# Mutable Data
##############################################################################
# current pill information
pillposition: # current position of the pill(relative to the top left pixel)
    .word 812, 684 #first is always either the left or bottom of the pill, second is always either the right or top of the pill
currentpillcolor: # the current color of the pill
    .word 0xff0000,0xff0000
isrotated: #the orientation of the current pill (1 for horizontal, 0 for vertical)
    .word 0
next_pill_color:
    .word 0xff0000,0xff0000

#current game board information
#1 = right, 2 = left, 3 = up, 4 = down, 5 = virus 
board_data: # This stores pointers on each pill to the other half of itself. It also stores viruses in their position
    .space 4096 # the number of pixels on the display

number_of_viruses:
    .word 4 #default of 4

gravity_speed:
    .word 30
number_of_pills_dropped:
    .word 0
    
prev_num_viruses:
    .word 4 # this is how many viruses were in the previous game
prev_game_speed:
    .word 30

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    jal draw_start_menu
    construct_field:
    # Initialize the game
    li $t1, 0x808080 # $t1 = grey
    lw $t0, ADDR_DSPL # $t0 contains the current point of the rectangle in memory
    lw $t2, bottle_start # $t2 contains the first position of the rectangle
    lw $t3, bottle_width # $t3 stores the width of the bottle
    lw $t4, bottle_height # $t4 stores the height of the bottle 
    lw $t5 bottleneck_height # $t5 stores the height of the bottleneck 
    lw $t6 bottleneck_start # $t6 contains the first position of the rectangle, will also store the current starting pixel per section
    add $t7, $zero, $zero # $t7 stores i for the loop
    
    add $t6, $t0, $t6 # $t6 = The starting point to draw the pixel bottleneck(top left edge of the neck)
    
create_bottle_body:
    # draw the body of the bottle
    
    draw_bottleneck:
        beq $t7, $t5, draw_bottleneck_end
        sw $t1, 0($t6) #draw current pixel grey
        sw $t1, 16($t6) #draw right pixel grey
        addi $t7, $t7, 1 # increment the drawing 1 row down 
        addi $t6, $t6, 128 # move to the next pixel on the display
        j draw_bottleneck
    draw_bottleneck_end:
        add $t7, $zero, $zero # $t7 stores i for the next loop - reset it for the loop
        add $t6, $t0, $t2 # $t2 = The starting point to draw the pixel bottle(top left edge of the bottle)
    draw_horizontal:
        beq $t7, $t3, draw_horizontal_end
        avoid_neck: # does not draw pixels on the bottleneck bottom
            addi $t8, $zero, 7 #stores the pixel on the left bottom of the bottleneck
            addi $t9, $zero, 9 #stores the pixel on the right bottom of the bottleneck
            rightpoint: #Checks if the current pixel is before the bottleneck's right corner
                ble $t7, $t9, leftpoint
                sw $t1, 0($t6) #draw current pixel grey
            leftpoint: #Checks if the current pixel is after the bottleneck's left corner
                bge $t7, $t8, avoid_neck_end
                sw $t1, 0($t6) #draw current pixel grey
        avoid_neck_end:
        sw $t1, 2688($t6) #draw bottom pixel grey
        addi $t7, $t7, 1 # increment the drawing 1 row down 
        addi $t6, $t6, 4 # move to the next pixel on the display
        
        j draw_horizontal
    draw_horizontal_end:
        add $t7, $zero, $zero # $t7 stores i for the next loop - reset it for the loop
        add $t6, $t0, $t2 # puts the starting pixel on the top left corner again
    draw_vertical:
        beq $t7, $t4, draw_starting_pill
        sw $t1, 0($t6) #draw current pixel grey
        sw $t1, 64($t6) #draw right pixel grey
        addi $t7, $t7, 1 # increment the drawing 1 row down 
        addi $t6, $t6, 128 # move to the next pixel on the display
        j draw_vertical
draw_starting_pill:
    jal draw_initial_pill
draw_viruses: #randomly draws the number of viruses specified into the board
li $t8, 0 #create a counter for the loop
lw $t9, number_of_viruses #store the number of viruses in $t2
draw_virus_loop:
beq $t8, $t9, game_loop
jal generate_virus
addi $t8, $t8, 1 #increment the loop counter
j draw_virus_loop

lw $s6, gravity_speed # this counts how many times per second the pill drops
# 1a. Check if key has been pressed
game_loop:
    beq $s6, 0, gravity_effect # drop the pill if the timer is reached
    la $a2, pillposition # load the current pill position to $a2 and $a3
	lw $a3, 4($a2)
	lw $a2, 0($a2)
    lw $t9, ADDR_DSPL               # $t9 = the base address for the display
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, save_location
    addi $s6, $s6, -1
    li $v0 , 32
    li $a0 , 1
    syscall
    j game_loop
    #drop the pill (gravity)
    gravity_effect:
    lw $s6, gravity_speed #restart the gravity timer
    j down_collision

    # 1b. Check which key has been pressed
    save_location:
        
    check_input:                    
        lw $s0, 4($t0)                  # Load second word from keyboard
        beq $s0, 0x71, end              # Check if the key q was pressed
        beq $s0, 0x61, left_collision   # Check if the key a was pressed
        beq $s0, 0x64, right_collision  # Check if the key d was pressed
        beq $s0, 0x73, down_collision   # Check if the key s was pressed
        beq $s0, 0x77, rotate_collison   # Check if the key w was pressed
        beq $s0, 0x70, pause_menu
        j game_loop
    # 2a. Check for collisions
    left_collision:
    li $v0, 0 #set the default output to 0
    jal check_left_collision # check if you can move left (will not run the next line if no)
    beq $v0, 1, sleep # if there is a collision, sleep and restart the loop
    j move_left #else, move the pill
    right_collision:
    li $v0, 0 #set the default output to 0
    jal check_right_collision # check if you can move right (will not run the next line if no)
    beq $v0, 1, sleep # if there is a collision, sleep and restart the loop
    j move_right #else, move the pill
    down_collision:
    li $v0, 0 #set the default output to 0
    jal check_down_collision # check if you can move down (if not and you still choose to move down, the pill will stay and a new default pill will be drawn.
    beq $v0, 1, drop_pill # if there is a collision, drop the pill and make a new current pill
    j move_down
    rotate_collison: 
    li $v0, 0 #set the default output to 0
    jal check_rotation_collision # check if you can move down (if not and you still choose to move down, the pill will stay and a new default pill will be drawn.
    beq $v0, 1, sleep  # if there is a collision, sleep and restart the loop
    j rotate #else, move the pill
    
    
	# 2b. Update locations (capsules)
	move_left:
    	# move the pill
    	addi $t1, $a2, -4 
    	addi $t2, $a3, -4 
    	la $t3, pillposition # store the address of the pill position in $t3
    	#store the new pill position
    	sw $t1, 0($t3)
    	sw $t2, 4($t3)
    	j redraw
	
	move_right:
    	# move the pill
    	addi $t1, $a2, 4 
    	addi $t2, $a3, 4 
    	la $t3, pillposition # store the address of the pill position in $t3
    	#store the new pill position
    	sw $t1, 0($t3)
    	sw $t2, 4($t3)
    	j redraw
	
	move_down:
    	# move the pill
    	addi $t1, $a2, 128 
    	addi $t2, $a3, 128 
    	la $t3, pillposition # store the address of the pill position in $t3
    	#store the new pill position
    	sw $t1, 0($t3)
    	sw $t2, 4($t3)
    	j redraw
	rotate:
    	# load the current pill orientation
    	lw $t1, isrotated
    	hori_rotate: # if pill is horizontal, move the right part of the pill up
        	beq $t1, 0, vert_rotate  
        	addi $t2, $a3, -132
        	la $t3, pillposition # store the address of the pill position in $t3
        	#store the new pill position
        	sw $t2, 4($t3)
        	
        	# change the orientation of the pill in memory
        	sw $zero, isrotated
        	j redraw
    	vert_rotate: #if pill is vertical, move the top part of the pill to the location of the bottom, and move the bottom part to the right
        	addi $t2, $a3, 132
        	la $t3, pillposition # store the address of the pill position in $t3
            sw $t2, 4($t3)	
            # change the orientation of the pill in memory
        	li $t1, 1
        	sw $t1, isrotated
    	#flip the colors(since the pill "rotates") 
    	la $t1, currentpillcolor
    	# take the current colors
    	lw $t2, 4($t1)
    	lw $t3, 0($t1)
    	#flip the colors around
    	sw $t2, 0($t1)
    	sw $t3, 4($t1)
	
	# 3. Draw the screen
	redraw:
	   jal redraw_pill
	   
	
	# 4. Sleep
    sleep:
        #check if gravity needs to increase
        lw $t1, number_of_pills_dropped
        bge $t1, 5, increase_gravity #if the number of pills dropped is 5 or more, increase the speed of gravity by 2
        j dont_increase_gravity
        increase_gravity:
        lw $t1, gravity_speed
        ble $t1, 5, set_gravity_max
        addi $t1, $t1, -1
        sw $t1, gravity_speed
        sw $zero, number_of_pills_dropped
        j dont_increase_gravity
        set_gravity_max:
        li $t1, 1
        sw $t1, gravity_speed
        dont_increase_gravity:
        li $v0 , 32
        li $a0 , 17
        syscall
    # 5. Go back to Step 1
    
    check_for_game_over:
    #this checks if the number of viruses is 0, if it is then the game ends
    lw $t2, number_of_viruses
    beq $t2, 0, new_level
    j check_if_lost # this checks if the user has lost
end:
    li $v0, 10                      # Quit gracefully
	syscall
	
# FUNCTIONS
redraw_pill: #deletes the first pill and then draws it in the new location
# arguments 
# $a2 = previous pill position 1
# $a3 = previous pill position 2
#set first pill position to be zero
lw $t0, ADDR_DSPL # $t0 contains the top left pixel address
add $t1, $a2, $t0 # $t1 is the address of the old pixel to be replaced
add $t2, $a3, $t0
#delete the pixel value
sw $zero, 0($t1)
sw $zero, 0($t2)
# set new pill position to contain correct colors
la $t1, pillposition
lw $t2, 0($t1) # load the value of the current pill position
lw $t3, 4($t1)
add $t2, $t2, $t0
add $t3, $t3, $t0

# find the correct color
la $t1, currentpillcolor
lw $t4, 0($t1)
lw $t5, 4($t1)
# draw the new pill(coordinate 1 = color 1, coordinate 2 = color 2)
sw $t4, 0($t2)
sw $t5, 0($t3)

jr $ra

draw_initial_pill: # draws a pill in the initial start location and sets it as the current pill
#arguments: None
    #choose a random pill color combination
    #set the curent pill color to the next pill color
    la $v0, next_pill_color
    lw $a1, 0($v0)
    lw $a0, 4($v0)
    la $v0, currentpillcolor
    sw $a1, 0($v0)
    sw $a0, 4($v0)
    
    li $v0, 42 #generate a random number between 1 and 6
    li $a1, 6
    li $a0, 0
    syscall
    la $t8, redred #find the address of the first color combo
    addi $t9, $zero, 0 # $t9 stores the number of iterations
    add $t2, $zero, $zero #initialize $t2 = i
    find_color_address:
    beq $t9, $a0, make_random_pill_end
        addi $t2, $t2, 8 # $t2 stores the number of bits needed to jump in memory to find the random color address
        addi $t9, $t9, 1 # increment the loop
        j find_color_address
    make_random_pill_end:
    add $t8, $t8, $t2 # $t8 stores the address of the random pill colors (first color address)
    lw $t4, 0($t8) #$t4 stores the first color in the pill
    lw $t5, 4($t8) # $t5 stores the second color of the pill
    la $t6, next_pill_color # store the address of the current pill color
    sw $t4, 0($t6) # store the current pill color thats in $t4 (first address)
    sw $t5, 4($t6) # store the current pill color thats in $t5 (second address)
    
    
    #set the position of the current pill as the default position (812, 684), and draw the pill with the correct colors(position1 = color1, position2 = color2)
    la $t1, pillposition # find the address of the pill position
    #set the pill to default position
    li $a2, 812
    li $a3, 684
    
    sw $a2, 0($t1)
    sw $a3, 4($t1)
    
    la $v0, currentpillcolor
    lw $t4, 0($v0)
    lw $t5, 4($v0)
    #draw the pill
    lw $t9, ADDR_DSPL
    add $t6, $t9, $a2 # the default position of the first pixel
    add $t7, $t9, $a3 # the default position of the second pixel
    sw $t4, 0($t6) # draw color1 into position1
    sw $t5, 0($t7) # draw color2 into position2
    
    #draw the next pill
    la $v0, next_pill_color
    lw $t4, 0($v0)
    lw $t5, 4($v0)
    #draw the pill
    lw $t9, ADDR_DSPL
    addi $t6, $t9, 1380  # the default position of the first pixel
    add $t7, $t9, 1508 # the default position of the second pixel
    sw $t4, 0($t6) # draw color1 into position1
    sw $t5, 0($t7) # draw color2 into position2
    
    #set the rotation of the pill to be 0
    la $t1, isrotated
    sw $zero, 0($t1)
    
    jr $ra #return
    
    
check_left_collision:
#arguments: $a2, $a3 = current pixel position
# return: $v0 = if there is a collision(1) or no collision(0)
#if the left of the capsule is non empty (either a wall or a capsule), then skip the movement and just go to sleep
    add $t1, $t9, $a2
    addi $t1, $t1, -4 # find the current position of the first pixel
    lw $t2, 0($t1) # find the contents of that pixel
    beq $t2, $zero, check_rotation_left # Check if the first pixel of the pill has something to its left - if yes, return 1, if no, check if the pill is vertical to see if the other half needs to be checked
        # else, return 1(collision already)
        li $v0, 1
        j end_left_collision
    check_rotation_left:# check if the pixel is rotated, if its not, 0 can be returned
        lw $t3, isrotated
        beq $t3, 1, end_left_collision #if the pixel is horizontal, check is satisfied
    check_secondhalf_left: # if the pixel next to the second pill half is also empty, return 0
        add $t1, $t9, $a3
        addi $t1, $t1, -4 # find the current position of the first pixel
        lw $t2, 0($t1) # find the contents of that pixel
        beq $t2, $zero, end_left_collision # if the pixel to the left is empty, move left
        # else, return 1
        li $v0, 1
    end_left_collision:
        jr $ra
        
check_right_collision:
#arguments: $a3, $a2 = current pixel position (reversed because the function is copycat of check left collision with the pixels reversed
# return: $v0 = if there is a collision(1) or no collision(0)
#if the right of the capsule is non empty (either a wall or a capsule), then skip the movement and just go to sleep
    lw $t9, ADDR_DSPL
    add $t1, $t9, $a3
    addi $t1, $t1, 4 # find the current position of the first pixel
    lw $t2, 0($t1) # find the contents of that pixel
    beq $t2, $zero, check_rotation_right # Check if the first pixel of the pill has something to its left - if yes, return 1, if no, check if the pill is vertical to see if the other half needs to be checked
        # else, return 1(collision already)
        li $v0, 1
        j end_right_collision
    check_rotation_right: # check if the pixel is rotated, if its not, 0 can be returned
        lw $t3, isrotated
        beq $t3, 1, end_right_collision #if the pixel is horizontal, check is satisfied
    check_secondhalf_right: # if the pixel next to the second pill half is also empty, return 0
        add $t1, $t9, $a2
        addi $t1, $t1, 4 # find the current position of the first pixel
        lw $t2, 0($t1) # find the contents of that pixel
        beq $t2, $zero, end_right_collision # if the pixel to the left is empty, move left
        # else, return 1
        li $v0, 1
    end_right_collision:
        jr $ra
        
check_down_collision:
#arguments: $a2, $a3 = current pixel position
# return: $v0 = if there is a collision(1) or no collision(0)
#if the bottom of the capsule is non empty (either a wall or a capsule), then skip the movement and just go to sleep
    lw $t9, ADDR_DSPL
    add $t1, $t9, $a2
    addi $t1, $t1, 128 # find the current position of the first pixel
    lw $t2, 0($t1) # find the contents of that pixel
    beq $t2, $zero, check_rotation_down # Check if the first pixel of the pill has something to its left - if yes, return 1, if no, check if the pill is vertical to see if the other half needs to be checked
        # else, return 1(collision already)
        li $v0, 1
        j end_down_collision
    check_rotation_down:# check if the pixel is rotated, if its not, 0 can be returned
        lw $t3, isrotated
        beq $t3, 0, end_down_collision #if the pixel is vertical, check is satisfied
    check_second: # if the pixel next to the second pill half is also empty, return 0
        add $t1, $t9, $a3
        addi $t1, $t1, 128 # find the current position of the first pixel
        lw $t2, 0($t1) # find the contents of that pixel
        beq $t2, $zero, end_down_collision # if the pixel to the left is empty, move left
        # else, return 1
        li $v0, 1
    end_down_collision:
        jr $ra

check_rotation_collision:
#arguments: $a2 = current location of the pill
# returns $v0 = 1 if there was a collision, 0 if not
#this function just needs to check if there is a block to the right of the bottom pill if the pill is vertical,
# and if there is a block above the left pill if it is horizontal
    lw $t1, isrotated
    beq $t1, 1, check_horizontal_rotation # this checks for collision if the pill is vertical
        add $t1, $t9, $a2
        addi $t1, $t1, 4 # find the current position of the first pixel
        lw $t2, 0($t1) # find the contents of that pixel
        beq $t2, $zero, end_rotation_collision #if there is no collision on the right, pill can be rotated
            li $v0, 1 
            j end_rotation_collision
    check_horizontal_rotation: # if the pill is horizontal
        add $t1, $t9, $a2
        addi $t1, $t1, -128 # find the current position of the first pixel
        lw $t2, 0($t1) # find the contents of that pixel
        beq $t2, $zero, end_rotation_collision #if there is no collision on the right, pill can be rotated
            li $v0, 1 
    end_rotation_collision:
        jr $ra

    
drop_pill: # function that drops the pill when it hits an object below and saves it to memory. Then, draw a new pill at the top of the bottle
#args:$a2 = the first position of the pill
#     $a3 = the second position of the pill
    #adds a pill to the pill counter
    lw $t1, number_of_pills_dropped
    addi $t1, $t1, 1
    sw $t1, number_of_pills_dropped
    #save the pill in the game board information
    la $t1, board_data #loads the first space in memory for the game board
    
    #check if the pill is vertical 
    lw $t2, isrotated #if $t2 = 0, the pill is vertical
    #if the pill is vertical, save it in memory
    add $t3, $t1, $a2 #$t3 stores the location of the first pill
    add $t4, $t1, $a3 #$t4 stores the location of the second pill
    beq $t2, 0, save_vertical
        #if the pill is horizontal
        li $t5, 1
        sw $t5, 0($t3) #store 1 in memory, meaning the other pill is to its right
        li $t5, 2
        sw $t5, 0($t4) #store 2 in memory, meaning the other pill is to its left
        j drop_pill_check_clears
    save_vertical:
        #if the pill is vertical
        li $t5, 3
        sw $t5, 0($t3) #store 3 in memory, meaning the other pill is above
        li $t5, 4
        sw $t5, 0($t4) #store 2 in memory, meaning the other pill is below
    drop_pill_check_clears:
    #check for clears
    jal check_clears
    
    #play the sound effect
    jal play_drop_sound
    #create a new pill
    jal draw_initial_pill
    
    j sleep




check_clears: # this function checks if four-in-a-row color combination was achieved vertically or horizontally, and clears those rows if achieved
    
    check_horizontal:
    li $s4, 0 #clear the flag that a change has occured
    addi $sp, $sp, -4 # save the return address
    sw $ra, 0($sp)
    #all rows must be checked, so the starting pixel has to go from the top left corner and iterativly be updated to the bottom left corner
    li $t1, 0 #initialise the loop counter
    lw $t8, bottle_height #initialise the number of columns to check
    addi $t8, $t8, -1 #-2 because the playing field doesnt include the borders
    lw $t3, bottle_start
    addi $t3, $t3, 132 #initialise the first pixel as one down and one to the right of the top left corner of the border.
    addi $a0, $t3, 0 # $a0 is the first pixel offset
    #loop: this will check the horizontal rows  for each row. every time the loop iterates, it should check the current pixel($a0) for clears,
    #change the current pixel to the pixel below, and increment the loop counter
    horizontal_check:
    beq $t1, $t8, check_vertical # finish horizontal check, move on
    jal check_horizontal_clear
    addi $a0, $a0, 128 #move the pixel over by 1 
    addi $t1, $t1, 1 # increment the loop counter
    j horizontal_check
    
    
    check_vertical:
    #all columns must be checked, so the starting pixel has to go from the top left corner and iterativly be updated to the top right corner
    li $t1, 0 #initialise the loop counter
    lw $t8, bottle_width #initialise the number of columns to check
    addi $t8, $t8, -2 #-2 because the playing field doesnt include the borders
    lw $t3, bottle_start
    addi $t3, $t3, 132 #initialise the first pixel as one down and one to the right of the top left corner of the border.
    addi $a0, $t3, 0 # $a0 is the first pixel offset
    #loop: this will check the vertical columns for each column. every time the loop iterates, it should check the current pixel($a0) for clears,
    #change the current pixel to the pixel to its right, and increment the loop counter
    vertical_check:
    beq $t1, $t8, check_recursively
    jal check_vertical_clear
    addi $a0, $a0, 4 #move the pixel over by 1 
    addi $t1, $t1, 1 # increment the loop counter
    j vertical_check
    check_unsupported:
    
    
    check_recursively:
    beq $s4, 0, end_check
    jal check_clears
    
    
    
    end_check:
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
    jr $ra

check_vertical_clear:
#This function checks a column for the same colors in a row - if more than 4 colors are the same, then that column is cleared
#args: $a0 = starting pixel to check(will always be at a border) - a0 will be the offset, not the actual location in memory
#returns: none - function calls itself recursivly(TODO) until all combinations are done
    
    #find the starting pixel in memory
    lw $t0, ADDR_DSPL
    add $t7, $t0, $a0 # $t7 tracks the current pixel being checked
    lw $t2, bottle_height #this is to see how many pixels you need to check vertically
    li $t3, 0 # $t3 stores a counter for the upcoming loop
    lw $t4, 0($t7) # this stores the current color of the pixel being checked
    li $t5, 1 #this counts how many pixels are the same color
    #Loop: This loop will start at the starting pixel, and check if the pixel below is the same color. If it is, it will increment $t5 by 1
    #If its not, it will reset $t5 to 0 and reset $t4 to be the new current color. 
    #every time it resets, it will check if $t5 was 4 or greater. If it was, call a function to remove that number of pixels from above the current pixel
    #if the current color is empty(black), immediatly go to the next iteration.
    vert_clear_start:
    beq $t3, $t2, vert_clear_end # this loop iterates $t2 times
   
    beq $t4, 0, check_if_clear_vert # if the current pixel is empty, go to the next iteration
    beq $t4, 0xcccccccc, check_if_clear_vert
    
    #check if the pixel below is the same color
    lw $t6, 128($t7) # $t6 stores the color of the pixel below
    beq $t4, $t6, same_color_vert
    #if the color below is not the same as the current color
    addi $t4, $t6, 0 #set $t4 to be the color of the pixel below
    check_if_clear_vert:
    bge $t5, 4, clear_lines_vertical # if the number of colors before it was greater or equal to 4, clear all pixels that were the same color
    #else, the number of colors was less than 4 and the loop just resets and moves on.
    li $t5, 1 #reset the counter of sequenced colors to 0
    
    j clear_lines_vertical_end
    clear_lines_vertical:
    addi $a0, $t7, 0 # set argument $a0 to the current pixel address
    addi $a1, $t5, 0 # set argument $a1 to the number of pixels that were the same color
    #save the return address to the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal play_clear_sound
    jal clear_vertical
    li $s4, 1 #add the flag that a change has occured
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
    li $t5, 1 #reset the counter of sequenced colors to 1
    clear_lines_vertical_end:
    j same_color_vert_end
    
    
    same_color_vert: # if the color below is the same as the current color
    addi $t5, $t5, 1 #increment the number of colors found by 1
    
    same_color_vert_end:
    addi $t7, $t7, 128 # move the current location of the pixel to the location below
    lw $t4, 0($t7) # this stores the current color of the pixel being checked
    addi $t3, $t3, 1 # increment the loop counter
    j vert_clear_start
    
    vert_clear_end:
    jr $ra
    
    
check_horizontal_clear:
#This function checks a row for the same colors in a row - if more than 4 colors are the same, then that row is cleared
#args: $a0 = starting pixel to check(will always be at a border) - a0 will be the offset, not the actual location in memory
#returns: none - function calls itself recursivly(TODO) until all combinations are done
    
    #find the starting pixel in memory
    lw $t0, ADDR_DSPL
    add $t7, $t0, $a0 # $t7 tracks the current pixel being checked
    lw $t2, bottle_width #this is to see how many pixels you need to check horizontally
    li $t3, 0 #$t3 stores a counter for the upcoming loop
    lw $t4, 0($t7) # this stores the current color of the pixel being checked
    li $t5, 1 #this counts how many pixels are the same color
    
    #Loop: This loop will start at the starting pixel, and check if the pixel beside is the same color. If it is, it will increment $t5 by 1
    #If its not, it will reset $t5 to 0 and reset $t4 to be the new current color. 
    #every time it resets, it will check if $t5 was 4 or greater. If it was, call a function to remove that number of pixels from above the current pixel
    #if the current color is empty(black), immediatly go to the next iteration.
    hori_clear_start:
    beq $t3, $t2, hori_clear_end # this loop iterates $t2 times
   
    beq $t4, $zero, check_if_clear_hori # if the current pixel is empty, go to the next iteration
    
    #check if the pixel below is the same color
    lw $t6, 4($t7) # $t6 stores the color of the pixel beside
    beq $t4, $t6, same_color_hori
    #if the color below is not the same as the current color
    addi $t4, $t6, 0 #set $t4 to be the color of the pixel below
    check_if_clear_hori:
    bge $t5, 4, clear_lines_horizontal # if the number of colors before it was greater or equal to 4, clear all pixels that were the same color
    #else, the number of colors was less than 4 and the loop just resets and moves on.
    li $t5, 1 #reset the counter of sequenced colors to 1
    
    j clear_lines_horizontal_end
    clear_lines_horizontal:
    addi $a0, $t7, 0 # set argument $a0 to the current pixel address
    addi $a1, $t5, 0 # set argument $a1 to the number of pixels that were the same color
    #save the return address to the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal play_clear_sound
    jal clear_horizontal
    li $s4, 1 #flag that checks if a clear occured
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
    li $t5, 1 #reset the counter of sequenced colors to 1
    clear_lines_horizontal_end:
    j same_color_hori_end
    
    
    same_color_hori: # if the color below is the same as the current color
    addi $t5, $t5, 1 #increment the number of colors found by 1
    
    same_color_hori_end:
    addi $t7, $t7, 4 # move the current location of the pixel to the location beside
    lw $t4, 0($t7) # this stores the current color of the pixel being checked
    addi $t3, $t3, 1 # increment the loop counter
    j hori_clear_start
    
    hori_clear_end:
    
    jr $ra
    
    
    
clear_vertical:
#arguments: $a0 = the pixel below what needs to be cleared, inclusive
#arguments: $a1 = the number of pixels that need to be cleared
# this function deletes $a1 pixels above $a0 from memory.
#note: DO NOT OVERRIDE $t3 and $t6
li $s5, 0 #loop counter initialized
addi $sp, $sp, -4
sw $ra, 0($sp)
#this loop will iterate $a1 times, each time it will delete what is currently at the current pixel address, then move to the pixel above
clear_vert_start:
beq $s5, $a1, end_clear_vertical
    #delete the pixel from the game board memory
    sw $zero, 0($a0) #delete the current pixel
    jal find_connecting_pixel
    beq $v1, 1, cascade_side
    beq $v1, 2, cascade_side
    j check_for_viruses_vertical
    cascade_side:
    #remove the pixel from the game data
    lw $t0, ADDR_DSPL
    sub $t0, $v0, $t0
    la $t9, board_data
    add $t9, $t9, $t0
    sw $zero, 0($t9)
    addi $a2, $v0, 128
    lw $t9, 0($a2)
    beq $t9, 0, do_cascade
    j check_for_viruses_vertical
    do_cascade:
    jal cascade
    check_for_viruses_vertical:
    bne $v1, 5, end_virus_check_vert
    jal clear_virus
    end_virus_check_vert:
    
    addi $a0, $a0, -128 #move the current pixel to the next pixel above
    addi $s5, $s5, 1 #increment the loop counter
    j clear_vert_start
end_clear_vertical:
addi $a2, $a0, 0 #save the current pixel that was deleted
jal cascade #cascade the values above
lw $ra, 0($sp) #find the return address again
addi $sp, $sp, 4
jr $ra


clear_horizontal:
#arguments: $a0 = the pixel below what needs to be cleared, inclusive
#arguments: $a1 = the number of pixels that need to be cleared
# this function deletes $a1 pixels to the left of $a0 from memory.
#note: DO NOT OVERRIDE $t3 and $t6
    li $s5, 0 #loop counter initialized
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    #this loop will iterate $a1 times, each time it will delete what is currently at the current pixel address, then move to the pixel above
    clear_hori_start:
    
    beq $s5, $a1, end_clear_horizontal
        sw $zero, 0($a0) #delete the current pixel
        addi $a2, $a0, 0 #save the current pixel that was deleted
        jal cascade #cascade the values above
        
        jal find_connecting_pixel
        #remove the pixel from the game data
        lw $t0, ADDR_DSPL
        sub $t0, $v0, $t0
        la $t9, board_data
        add $t9, $t9, $t0
        sw $zero, 0($t9)
        bne $v1, 5, end_virus_check_hori
        jal clear_virus
        end_virus_check_hori:
        addi $a0, $a0, -4 #move the current pixel to the next pixel to the left
        addi $s5, $s5, 1 #increment the loop counter
        
        j clear_hori_start
    end_clear_horizontal:
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
    jr $ra

cascade:
# this function takes a cleared block, and any subsequent consecutive blocks above it will fall down until they reach the bottom
#arguments: $a2 = the pixel position that was cleared (address in memory)
#returns: none, moves all pixels above the cleared pixel down
    
   
    lw $t6, -128($a2) #$t6 stores the current color of the pixel above the current pixel
    #loop: check the block above the current pixel. If it is occupied, change the color of the current pixel to the pixel above.
    #then, change the current pixel to be the newly empty pixel. incremement the loop and continue looping. Once the final pixel above is empty or grey,
    #end the loop
    addi $s2, $a2, 0 #store the original pixel in memory
    begin_cascade:
    #if the pixel above is a virus, end the cascade
    addi $sp, $sp, -4
    sw $ra, 0($sp) #save the return address
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    addi $a0, $s2, 128 #set arg a0 to be the current pixel
    addi $sp, $sp, -4
    sw $t6, 0($sp) #save the current value of $t6 in the stack
    jal find_connecting_pixel
    lw $t6, 0($sp) #find the original t6 again
    addi $sp, $sp, 4
    lw $a0, 0($sp) #find the original a0 again
    addi $sp, $sp, 4
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
   
    
    bne $a0, 5, end_virus_check_cascade
    #if the block above is a virus
    j end_cascade
    end_virus_check_cascade:
    beq $t6, $zero, end_cascade #if the block above the current pixel is empty, the cascade is done
    sw $t6, 0($s2) # store the color above into the color of the current pixel
    addi $s2, $s2, -128 # change the current pixel to be the pixel above
    sw $zero, 0($s2) #turn the current pixel to black
    lw $t6, -128($s2) # $t6 stores the current color of the pixel above the current pixel
    
    #move the cascaded pixels in game board memory
    lw $t0, ADDR_DSPL
    sub $t0, $a2, $t0
    la $t9, board_data
    add $t9, $t9, $t0 # $t9 stores the pixel position in game board memory
    lw $s3, -128($t9)
    sw $s3, 0($t9) #replace the pixel address with the pixel address above
    sw $zero, -128($t9) #delete the pixel address above
    
    
    j begin_cascade
    end_cascade:
    
    #check if the pixel below the original pixel was empty
    lw $t6, 128($a2) # stores the color of the pixel below the starting pixel
    beq $t6, $zero, recurse_cascade
    jr $ra
    
    recurse_cascade: #recusvily call the cascade function again so the cascade occurs the entire way down
    addi $a2, $a2, 128
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal cascade 
    lw $ra, 0($sp) #find the return address again
    addi $sp, $sp, 4
    jr $ra
    

generate_virus:
#This function generates a virus(one pixel) at a random location (with a random color) on the lower half of the playing field.
#args:None
#returns: None - draws the viruses to the screen and saves their location in the game board as a virus
    addi $sp, $sp, -4
    sw $ra, 0($sp) #save the return address to the stack
    jal generate_random_color #store a random color in $v1
    
    lw $t1, bottle_width
    addi $t1, $t1, -2 #save the amount of pixels between the border width
    li $v0, 42 #generate a random number between 0 and the bottle width size
    addi $a1, $t1, 0
    li $a0, 0
    syscall
    
    li $t2, 4
    mult $a0, $t2 #convert from bits to bytes
    mflo $t3 #save the horizontal position offset in $t3
    
    li $t1, 10
    li $v0, 42 #generate a random number between 0 and the bottle width size
    addi $a1, $t1, 0
    li $a0, 0 #only should generate pixels on the lower half
    syscall
    addi $a0, $a0, 10
    li $t2, 128
    mult $a0, $t2 #convert from bits to bytes
    mflo $t4 #save the vertical position offset in $t4
    add $t5, $t3, $t4 #find the total offset of the random position
    
    #store the virus position in the game board information in memory
    la $t0, board_data 
    add $t0, $t0, $t5
    addi $t0, $t0, 1040
    li $t1, 5
    sw $t1, 0($t0) #store 5 into the position of the virus in the game board information
    
    #find the starting pixel address
    lw $t0, ADDR_DSPL 
    lw $t1, bottle_start
    addi $t1, $t1, 132 #first pixel is diagonally down and to the right ofthe corner of the border.
    add $t2, $t1, $t0 #$t2 stores the starting address of the pixel on the top left
    add $t2, $t2, $t5 #store the random pixel generated in $t2
    
    sw $v1, 0($t2) #store the random color in memory display
    
    lw $ra, 0($sp) #retrieve the return address
    addi $sp, $sp, 4
    jr $ra
    
    
generate_random_color:
#args:none
#returns: $v1 = the address of a random color out of the color combinations in memory (returns only the address of the first color)
    li $v0, 42 #generate a random number between 1 and 6
    li $a1, 6
    li $a0, 0
    syscall
    la $t1, redred #$t1 stores the address of the first color combination in data
    li $t2, 8 
    mult $t2, $a0 # multiply the random number by 8 to move the address that many colors forward
    mflo $t2 #$t2 stores the number of address bits that need to be jumped
    add $t1, $t2, $t1 # stores the number of the random color address in $t1
    lw $v1, 0($t1) #store the random color in $v1
    jr $ra
    
find_connecting_pixel:
# This function finds the pixel half that is connected to the pixel in question
#args: $a0 = the pixel position who's neighbor is being looked for in memory
#returns: $v0 = the position of the pixel connected to it (return 0 if it is a lone half pixel) in memory
#returns: $v1 = the direction where the pixel beside it was (returns 0 if it is a lone half pixel)
#if the pixel is a virus then return $v1 = 5
    la $t7, board_data #find the first position in board data
    lw $t6, ADDR_DSPL
    sub $t4, $a0, $t6 #find the position of the pixel in offsets, not address
    add $t5, $t4, $t7 #stores the position of the pixel in game board data
    lw $v1, 0($t5) #$v1 stores the direction to its connecting pixel
    
    #if the direction is 0, then the pixel has already been split and it is a lone half pill
    beq $v1, 0, check_lone
    beq $v1, 1, check_if_right
    beq $v1, 2, check_if_left
    beq $v1, 3, check_if_up
    beq $v1, 4, check_if_down
    beq $v1, 5, check_lone
    j return_connecting_pixel
    check_if_right:
    addi $v0, $a0, 4 #return pixel is the pixel to the right
    j return_connecting_pixel
    
    check_if_left:
    addi $v0, $a0, -4 #return pixel is the pixel to the left
    j return_connecting_pixel
    
    check_if_up:
    addi $v0, $a0, -128 #return pixel is the pixel above
    j return_connecting_pixel
    
    check_if_down:
    addi $v0, $a0, 128 #return pixel is the pixel below
    j return_connecting_pixel
    check_lone:
    addi $v0, $a0, 0
    j return_connecting_pixel
    return_connecting_pixel:
    jr $ra #return


clear_virus:
#this function removes the number of viruses in the num_viruses data portion by 1, and deletes the virus marker in the board data.
#args: $a0 = the position of the virus being cleared
#returns: None - clears the virus from the required data structures
    lw $t4, number_of_viruses
    addi $t4, $t4, -1 #remove one from the number of viruses
    sw $t4, number_of_viruses #update the number of viruses in data
    
    #remove the virus from the game board
    la $t9, board_data
    lw $t6, ADDR_DSPL
    sub $t4, $a0, $t6 #find the position of the pixel in offsets, not address
    add $t5, $t4, $t9 #stores the position of the pixel in game board data
    sw $zero, 0($t5) #delete the virus
    
    jr $ra #return
        
        
        


check_if_lost:
# This function checks if the neck of the bottle(three pixels inside the bottom of the bottleneck) are full. If they are, the game ends.
#args: None
    la $t1, board_data #get the board data
    lw $t2, bottle_start
    addi $t3, $t2, 32 #find the first pixel to check if full 
    
    #save the positions of these three pixels from the game data
    add $t3, $t1, $t3 
    lw $t4, 0($t3)
    lw $t5, 4($t3)
    lw $t6, 8($t3)
    
    #check if all three are empty, if not, the game ends
    bne $t5, 0, game_over
    bne $t4, 0, game_over
    bne $t6, 0, game_over
    j game_loop #if the game is not over, continue from the start of the game loop
    game_over:
    jal play_game_over_sound
    j game_over_screen
    
game_over_screen:
#draw a game over screen
#delete the board
jal delete_board
#save white as a color
li $t0, 0xffffff #set $t0 to white
lw $t1, ADDR_DSPL
addi $t1, $t1, 1304 # the start of the g

#draw a g
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 516($t1)
sw $t0, 520($t1)
sw $t0, 524($t1)
sw $t0, 396($t1)
sw $t0, 268($t1)
sw $t0, 264($t1)

#draw an A
addi $t1, $t1, 24 # the start of the a
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 124($t1)
sw $t0, 136($t1)
sw $t0, 252($t1)
sw $t0, 256($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)
sw $t0, 380($t1)
sw $t0, 508($t1)
sw $t0, 392($t1)
sw $t0, 520($t1)

#draw an m
addi $t1, $t1, 16 # the start of the m
sw $t0, 0($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 16($t1)
sw $t0, 144($t1)
sw $t0, 272($t1)
sw $t0, 400($t1)
sw $t0, 528($t1)
sw $t0, 132($t1)
sw $t0, 264($t1)
sw $t0, 140($t1)

#draw an e
addi $t1, $t1, 24 # the start of the m
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 516($t1)
sw $t0, 520($t1)
sw $t0, 524($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)

lw $t1, ADDR_DSPL
addi $t1, $t1, 2072 # the start of the O
#draw an O
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 516($t1)
sw $t0, 520($t1)
sw $t0, 524($t1)
sw $t0, 140($t1)
sw $t0, 268($t1)
sw $t0, 396($t1)

#draw a V
addi $t1, $t1, 20 # the start of the v
sw $t0, 0($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 260($t1)
sw $t0, 388($t1)
sw $t0, 392($t1)
sw $t0, 396($t1)
sw $t0, 520($t1)
sw $t0, 268($t1)
sw $t0, 272($t1)
sw $t0, 144($t1)
sw $t0, 16($t1)

#draw an E
addi $t1, $t1, 24 # the start of the e
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 516($t1)
sw $t0, 520($t1)
sw $t0, 524($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)

#draw an r
addi $t1, $t1, 20 # the start of the r
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)
sw $t0, 268($t1)
sw $t0, 392($t1)
sw $t0, 524($t1)
sw $t0, 140($t1)

# draw a rectangle that holds the retry text
addi $t1, $t1, 928 # the start of the rectangle
#draw the top
li $t3, 0 #counter
draw_rect_horizontal:
beq $t3, 29, end_rect_horizontal
sw $t0, 0($t1)
sw $t0, 1024($t1)
addi $t1, $t1, -4
addi $t3, $t3 1
j draw_rect_horizontal
end_rect_horizontal:
li $t3, 0
draw_rect_vertical:
beq $t3, 9, end_rect_vertical
sw $t0, 0($t1)
sw $t0, 116($t1)
addi $t1, $t1, 128

addi $t3, $t3, 1
j draw_rect_vertical
end_rect_vertical:

#draw the r in retry
addi $t1, $t1, -888 # the start of the rectangle
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)
sw $t0, 268($t1)
sw $t0, 392($t1)
sw $t0, 524($t1)
sw $t0, 140($t1)

#draw the e
addi $t1, $t1, 20 # the start of the e
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 516($t1)
sw $t0, 520($t1)
sw $t0, 524($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)

#draw the T
addi $t1, $t1, 20 # the start of the e
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 16($t1)
sw $t0, 136($t1)
sw $t0, 264($t1)
sw $t0, 392($t1)
sw $t0, 520($t1)
#draw the r
addi $t1, $t1, 24 # the start of the rectangle
sw $t0, 0($t1)
sw $t0, 4($t1)
sw $t0, 8($t1)
sw $t0, 12($t1)
sw $t0, 128($t1)
sw $t0, 256($t1)
sw $t0, 384($t1)
sw $t0, 512($t1)
sw $t0, 260($t1)
sw $t0, 264($t1)
sw $t0, 268($t1)
sw $t0, 392($t1)
sw $t0, 524($t1)
sw $t0, 140($t1)

#draw the y
addi $t1, $t1, 20 # the start of the e
sw $t0, 0($t1)
sw $t0, 16($t1)
sw $t0, 132($t1)
sw $t0, 140($t1)
sw $t0, 264($t1)
sw $t0, 392($t1)
sw $t0, 520($t1)

game_over_loop:
# this happens if the user loses, they must press retry to start the game again, if not, the game over screen is shown.
    lw $t9, ADDR_DSPL               # $t9 = the base address for the display
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, check_for_retry      # If first word 1, key is pressed
    b game_over_loop
    
    check_for_retry: # check if the user inputed R
        lw $s0, 4($t0)                  # Load second word from keyboard
        beq $s0, 0x72, restart_game      # Check if the key r was pressed
        beq $s0, 0x71, end
        j game_over_loop
    restart_game:
    #this has to reset the entire mutable memory and restart the program
    jal delete_board
    #delete the current pill data
    la $t1, isrotated
    
    la $t1, board_data
    li $t2, 0 #coutner for the loop
    clear_board_data:
    beq $t2, 1024, end_clean_board_data
        sw $zero, 0($t1)
        addi $t1, $t1, 4
        addi $t2, $t2, 1
        j clear_board_data
    end_clean_board_data:
    #reset the number of viruses
    li $t2, 4
    sw $t2, number_of_viruses
    j main

delete_board:
#this deletes the entire bitmap contents
    lw $t0, ADDR_DSPL
    li $t1, 0
    sw $zero, number_of_pills_dropped #reset the number of pills dropped
    li $t2, 30
    sw $t1, gravity_speed #reset the gravity speed
    li $v0, 0
    li $v1, 0
    li $a0, 0
    li $a1, 0
    li $a2, 0
    li $a3, 0
    li $s0, 0
    li $s1, 0
    li $s2, 0
    li $s3, 0
    li $s4, 0
    li $s5, 0
    li $s6, 0
    
    delete_board_start:
    beq $t1, 1024, delete_board_end
        sw $zero, 0($t0) #delete the current pixel
        addi $t1, $t1, 1 #increment the loop counter
        addi $t0, $t0, 4 #move the pixel to the next
        j delete_board_start
    delete_board_end:
    jr $ra
    
    draw_start_menu:
    #this function draws a start menu with options to choose the game difficulty
    #draw the menu
    lw $t1, ADDR_DSPL
    li $t0, 0xffffff #set $t0 to white
    addi $t1, $t1, 400 #find first pixel
    #draw C
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 256($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw h
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 136($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 520($t1)
    
    #draw o
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 136($t1)
    sw $t0, 256($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw o
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 136($t1)
    sw $t0, 256($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw s
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw an e
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw m
    addi $t1, $t1, 688
    sw $t0, 0($t1)
    sw $t0, 16($t1)
    sw $t0, 128($t1)
    sw $t0, 132($t1)
    sw $t0, 140($t1)
    sw $t0, 144($t1)
    sw $t0, 256($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 264($t1)
    sw $t0, 272($t1)
    sw $t0, 400($t1)
    sw $t0, 528($t1)
    
    #draw o
    addi $t1, $t1, 24
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 136($t1)
    sw $t0, 256($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw d
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 128($t1)
    sw $t0, 136($t1)
    sw $t0, 256($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 392($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    
    #draw e
    addi $t1, $t1, 16
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 128($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    
    #draw e
    addi $t1, $t1, 1352
    sw $t0, 0($t1)
    sw $t0, 4($t1)
    sw $t0, 8($t1)
    sw $t0, 12($t1)
    sw $t0, 128($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 516($t1)
    sw $t0, 520($t1)
    sw $t0, 524($t1)
    
    #draw m
    addi $t1, $t1, 36
    sw $t0, 0($t1)
    sw $t0, 16($t1)
    sw $t0, 128($t1)
    sw $t0, 132($t1)
    sw $t0, 140($t1)
    sw $t0, 144($t1)
    sw $t0, 256($t1)
    sw $t0, 384($t1)
    sw $t0, 512($t1)
    sw $t0, 264($t1)
    sw $t0, 272($t1)
    sw $t0, 400($t1)
    sw $t0, 528($t1)
    
    #draw an h
    addi $t1, $t1, 40
    sw $t0, 0($t1)
    sw $t0, 12($t1)
    sw $t0, 128($t1)
    sw $t0, 140($t1)
    sw $t0, 256($t1)
    sw $t0, 260($t1)
    sw $t0, 264($t1)
    sw $t0, 268($t1)
    sw $t0, 384($t1)
    sw $t0, 396($t1)
    sw $t0, 512($t1)
    sw $t0, 524($t1)
    start_loop:
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, check_for_difficulty
    j start_loop
    
        
    	
    check_for_difficulty:                    
        lw $s0, 4($t0)                  # Load second word from keyboard
        beq $s0, 0x71, end              # Check if the key q was pressed
        beq $s0, 0x65, easy_mode   # Check if the key e was pressed
        beq $s0, 0x6D, medium_mode  # Check if the key m was pressed
        beq $s0, 0x68, hard_mode  # Check if the key h was pressed
        j start_loop
        easy_mode:
        li $t1, 30
        sw $t1, gravity_speed #set the gravity speed to the easy mode speed
        sw $t1, prev_game_speed
        li $t1, 4
        sw $t1, number_of_viruses # set the number of viruses to be the easy difficulty
        sw $t1, prev_num_viruses
        j start_game
        medium_mode:
        li $t1, 20
        sw $t1, gravity_speed #set the gravity speed to the medium mode speed
        sw $t1, prev_game_speed
        li $t1, 7
        sw $t1, number_of_viruses # set the number of viruses to be the medium difficulty
        sw $t1, prev_num_viruses
        j start_game
        hard_mode:
        li $t1, 15
        sw $t1, gravity_speed #set the gravity speed to the hard mode speed
        sw $t1, prev_game_speed
        li $t1, 10
        sw $t1, number_of_viruses # set the number of viruses to be the hard difficulty
        sw $t1, prev_num_viruses
        j start_game
        
        start_game:
        lw $t0, ADDR_DSPL
        li $t1, 0
        delete_menu:
        beq $t1, 1024, delete_board_end_menu
        sw $zero, 0($t0) #delete the current pixel
        addi $t1, $t1, 1 #increment the loop counter
        addi $t0, $t0, 4 #move the pixel to the next
        j delete_menu
        delete_board_end_menu:
        jr $ra

new_level:
#this will increase the number of viruses from the last level by 3, and reset the board and data
    jal play_win_sound
    jal delete_board
    lw $t1, prev_num_viruses
    addi $t1, $t1, 1
    sw $t1, number_of_viruses
    sw $t1, prev_num_viruses
    lw $t1, prev_game_speed
    sw $t1, gravity_speed
    j construct_field
    
    
pause_menu:
#This function starts a loop that pauses the game until the user presses p again - draws a p on the side

#draw a p
lw $t9, ADDR_DSPL
li $t0, 0xffffff #set $t0 to white
addi $t9, $t9, 484 #find first pixel
sw $t0, 0($t9)
sw $t0, 4($t9)
sw $t0, 8($t9)
sw $t0, 12($t9)
sw $t0, 128($t9)
sw $t0, 256($t9)
sw $t0, 384($t9)
sw $t0, 512($t9)
sw $t0, 260($t9)
sw $t0, 264($t9)
sw $t0, 268($t9)
sw $t0, 140($t9)

pause_loop:
    lw $t9, ADDR_DSPL               # $t9 = the base address for the display
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, check_for_unpause      # If first word 1, key is pressed
    b pause_loop
    
    check_for_unpause: # check if the user inputed R
        lw $s0, 4($t0)                  # Load second word from keyboard
        beq $s0, 0x70, delete_p      # Check if the key r was pressed
        beq $s0, 0x71, end              #check if q was pressed
        j pause_loop
    delete_p:
    #delete the p
    lw $t9, ADDR_DSPL
    li $t0, 0x0 #set $t0 to white
    addi $t9, $t9, 484 #find first pixel
    sw $t0, 0($t9)
    sw $t0, 4($t9)
    sw $t0, 8($t9)
    sw $t0, 12($t9)
    sw $t0, 128($t9)
    sw $t0, 256($t9)
    sw $t0, 384($t9)
    sw $t0, 512($t9)
    sw $t0, 260($t9)
    sw $t0, 264($t9)
    sw $t0, 268($t9)
    sw $t0, 140($t9)
    j game_loop
    
play_drop_sound:
#this plays the sound effect to drop a pill
#save $a0, $a1, $a2, $a3 in the stack
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    addi $sp, $sp, -4
    sw $a1, 0($sp)
    addi $sp, $sp, -4
    sw $a2, 0($sp)
    addi $sp, $sp, -4
    sw $a3, 0($sp)
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    addi $sp, $sp, -4
    sw $v0, 0($sp)
    la $t0, drop_sound
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lw $a2, 8($t0)
    lw $a3, 12($t0)
    li $v0, 31
    syscall
    lw $v0, 0($sp)
    addi $sp, $sp, 4
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    lw $a3, 0($sp)
    addi $sp, $sp, 4
    lw $a2, 0($sp)
    addi $sp, $sp, 4
    lw $a1, 0($sp)
    addi $sp, $sp, 4
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
play_clear_sound:
#this plays the sound effect to drop a pill
#save $a0, $a1, $a2, $a3 in the stack
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    addi $sp, $sp, -4
    sw $a1, 0($sp)
    addi $sp, $sp, -4
    sw $a2, 0($sp)
    addi $sp, $sp, -4
    sw $a3, 0($sp)
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    addi $sp, $sp, -4
    sw $v0, 0($sp)
    la $t0, clear_line_sound
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lw $a2, 8($t0)
    lw $a3, 12($t0)
    li $v0, 31
    syscall
    lw $v0, 0($sp)
    addi $sp, $sp, 4
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    lw $a3, 0($sp)
    addi $sp, $sp, 4
    lw $a2, 0($sp)
    addi $sp, $sp, 4
    lw $a1, 0($sp)
    addi $sp, $sp, 4
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
    play_game_over_sound:
#this plays the sound effect to drop a pill
#save $a0, $a1, $a2, $a3 in the stack
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    addi $sp, $sp, -4
    sw $a1, 0($sp)
    addi $sp, $sp, -4
    sw $a2, 0($sp)
    addi $sp, $sp, -4
    sw $a3, 0($sp)
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    addi $sp, $sp, -4
    sw $v0, 0($sp)
    la $t0, game_over_sound
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lw $a2, 8($t0)
    lw $a3, 12($t0)
    li $v0, 31
    syscall
    lw $v0, 0($sp)
    addi $sp, $sp, 4
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    lw $a3, 0($sp)
    addi $sp, $sp, 4
    lw $a2, 0($sp)
    addi $sp, $sp, 4
    lw $a1, 0($sp)
    addi $sp, $sp, 4
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
play_win_sound:
#this plays the sound effect to drop a pill
#save $a0, $a1, $a2, $a3 in the stack
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    addi $sp, $sp, -4
    sw $a1, 0($sp)
    addi $sp, $sp, -4
    sw $a2, 0($sp)
    addi $sp, $sp, -4
    sw $a3, 0($sp)
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    addi $sp, $sp, -4
    sw $v0, 0($sp)
    la $t0, win_sound
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lw $a2, 8($t0)
    lw $a3, 12($t0)
    li $v0, 31
    syscall
    lw $v0, 0($sp)
    addi $sp, $sp, 4
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    lw $a3, 0($sp)
    addi $sp, $sp, 4
    lw $a2, 0($sp)
    addi $sp, $sp, 4
    lw $a1, 0($sp)
    addi $sp, $sp, 4
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    jr $ra
