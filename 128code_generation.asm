.include "img_info.asm"
.include "data.asm"

	.data

imgInfo: .space	28	# image descriptor

	.align 2		# word boundary alignment
dummy:		.space 2
bmpHeader:	.space	BMPHeader_Size
		.space  1024	# enough for 256 lookup table entries

	.align 2
imgData: 	.space	MAX_IMG_SIZE

ifname:	.asciz "background.bmp"
ofname:	.asciz "result.bmp"

text_in:	.asciz	"ARKO1234_2024"

	.text
main:
	# initialize image descriptor
	# stores defined bmp_header values in imgInfo by given in img_info "struct" offset
	la a0, imgInfo
	la t0, ifname	# input file name
	sw t0, ImgInfo_fname(a0)
	la t0, bmpHeader
	sw t0, ImgInfo_hdrdat(a0)
	la t0, imgData
	sw t0, ImgInfo_imdat(a0)
	
	jal	read_bmp
	
	bnez a0, main_failure

	la a0, imgInfo
	la a4, text_in
	
	jal code_prepare

	la a0, imgInfo
	la t0, ofname
	sw t0, ImgInfo_fname(a0)
	jal save_bmp

main_failure:			# main_failure also ends programs without failures
	li a7, 10
	ecall
	
code_prepare:
	mv t2, a4
	mv t1, zero
	
code_prepare_loop:
	lb t0, 0(t2)
	addi t1, t1, 1
	addi t2, t2, 1
	bnez t0, code_prepare_loop
	
	addi t1, t1, -1		# saves number of signs to encode
	li t2, 11		# number of bits encoding each sign
	mul t1, t1, t2
	addi t1, t1, 55		# 11 - start sign, 11 - check sign, 13 - stop sign, 10 - quiet zone at start, 10 - quiet zone at end
	
	lw a1, ImgInfo_width(a0)	# amount of pixels in line
	
	blt a1, t1, main_failure
	
	sub t0, a1, t1		# space in pixels left after saving 128-barcode
	srli t0, t0, 2		# division by 2 gives amount of bytes of left in bmp space, division by 4 gives margin both at begining and at the end 
				# (margin can differ by 1 or 2 pixels, depending on that if barcode length in pixels is even)

encode_text:
	lw a1, ImgInfo_imdat(a0) # address of image data
	li a2, 0x1		# stores info if it's left or right 4 bits in byte (starts with 1 cause before setting first pixel it's xor-ed to 0)
	
	mv t5, zero		# it's check sign value counter
	mv t6, a4		# stores beggining address of text_in in a3 to count index
	
add_quiet_zone_front:
	add a1, a1, t0		# sets barcode margin in bmp (margin stored in t0)
	addi a1, a1, 5		# length of quiet zone 5 bytes = 10 pixels

add_start_sign:
	la t2, codes		# ptr to coding table
	lhu t0, startB_offset
	add t2, t2, t0
	add t5, t5, t0		# check sign value counter
	
	j prep_encode_sign	# skips encode_text_loop, saves start_B code and then goes to loop to code given tex

encode_text_loop:
	lbu t0, 0(a4)		# next bytes/signs of the text to encode
	beqz t0, add_check_sign
	addi a4, a4, 1
	
	la t2, codes
	addi t0, t0, -32	# in ASCII '0' is 48, in coding table it's idx 16 but every halfword is stored every 2 bytes so it's adrress no. 32, so the difference is 16
	slli t0, t0, 1		# equal to multiplying by 2 - halfword is 2 bytes, so id 16 starts on 32 byte 
	
	add t2, t2, t0
	sub t1, a4, t6		# stores index of text_in sign in t1
	mul t0, t0, t1		# multiplies sign number in coding table by index in text to encode
	add t5, t5, t0		# check sign value counter
	
prep_encode_sign:
	lhu t0, 0(t2)		# pobiera półsłowo do zakodowania
	li t4, 11		# czytamy 11 bitów z półsłowa
	
separate_bits:
	beqz t4, encode_text_loop
	
	# Separating bits
	andi t2, t0, 0x400	# t4 saves separated bit - 1 or 0, t0 11-bits word, t2 11-bits mask with 11th bit from LSB set to 1
	addi t4, t4, -1
	slli t0, t0, 1
	
	add a1, a1, a2		# if a6 is 1 - last 4 bits in byte, only then we increament x coordinate
	xori a2, a2, 0x1	# changes value of a6 - flag showing if it's first four or secound four bits counting from MSB
	
	beqz t2, separate_bits
	li a3, 0xF		# color set to black
	
set_pixel:
	andi a3, a3, 0xF	# mask the colour
	slli a3, a3, 4
	
	slli t1, a2, 2

	lbu  t2, -1(a1)		# load 2 pixels
	sll  t2, t2, t1		# pixel bit on the msb of the lowest byte - depending on the offset in t1

	li   t3, 0xF0F
	and  t2, t2, t3  	# mask the pixel color
	or   t2, t2, a3

	srl  t2, t2, t1
	sb   t2, -1(a1)		# store 2 pixels
	
	j separate_bits
	
add_check_sign:
	lhu t0, check_sign_divisor
	srli t5, t5, 1		# divison by 2 - to have original coding table values
	rem t5, t5, t0
	slli t5, t5, 1		# multiplication by 2 to have orginal coding table value mirrored to index in my coding table (values stored every 2 bytes - halfwords)
	la t2, codes		# ptr to coding table
	add t2, t2, t5
	lhu t0, 0(t2)
	
	li t4, 11
	
separate_check_sign_bits:
	beqz t4, add_stop_sign

	andi t2, t0, 0x400
	addi t4, t4, -1
	slli t0, t0, 1
	
	add a1, a1, a2		# if a2 is 1 - points last 4 bits in byte, only then we increament x coordinate
	xori a2, a2, 0x1	# changes value of a6 - flag whowing if it's first four or secound four bits counting from MSB
	
	beqz t2, separate_check_sign_bits
	li a3, 0xF		# color set to black
	
set_check_sign_pixel:
	andi a3, a3, 0xF	# mask the colour
	slli a3, a3, 4
	
	slli t1, a2, 2

	lbu  t2, -1(a1)		# load 2 pixels
	sll  t2, t2, t1		# pixel bit on the msb of the lowest byte - depending on the offset in t1

	li   t3, 0xF0F
	and  t2, t2, t3  	# mask the pixel color
	or   t2, t2, a3

	srl  t2, t2, t1
	sb   t2, -1(a1)		# store 2 pixels
	
	j separate_check_sign_bits
	
add_stop_sign:
	la t2, codes
	lhu t0, stop_offset
	add t2, t2, t0
	lhu t0, 0(t2)

	li t4, 13		# stop sign has 13 bits
	
separate_stop_sign_bits:
	beqz t4, add_quiet_zone_end

	li t1, 0x1000
	and t2, t0, t1
	addi t4, t4, -1
	slli t0, t0, 1
	
	add a1, a1, a2		# if a2 is 1 - points last 4 bits in byte, only then we increament x coordinate
	xori a2, a2, 0x1	# changes value of a2 - flag whowing if it's first four or secound four bits counting from MSB
	
	beqz t2, separate_stop_sign_bits
	li a3, 0xF		# color set to black
	
set_stop_sign_pixel:
	andi a3, a3, 0xF	# mask the colour
	slli a3, a3, 4
	
	slli t1, a2, 2

	lbu  t2, -1(a1)		# load 2 pixels
	sll  t2, t2, t1		# pixel bit on the msb of the lowest byte - depending on the offset in t1

	li   t3, 0xF0F
	and  t2, t2, t3  	# mask the pixel color
	or   t2, t2, a3

	srl  t2, t2, t1
	sb   t2, -1(a1)		# store 2 pixels
	
	j separate_stop_sign_bits
	
add_quiet_zone_end:
	li t0, 5		# length of quiet zone
	
add_quiet_zone_end_loop:
	addi a1, a1, 1 
	addi t0, t0, -1
	bnez t0, add_quiet_zone_end_loop

write_lines:
	lw a1, ImgInfo_imdat(a0)
	lw a2, ImgInfo_lbytes(a0)
	lw a3, ImgInfo_height(a0)	# height in pixels
	
	mul t1, a3, a2 		# size of whole image in bytes (height * line_bytes) - offset of end from start
	add t1, t1, a1		# address of last byte in img
	
	add a2, a1, a2		# first byte in img second line
	
write_line_loop:
	lw t0, 0(a1)
	sw t0, 0(a2)
	addi a1, a1, 4
	addi a2, a2, 4
	bne t1, a2, write_line_loop

exit:
	jr ra
