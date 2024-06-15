#-------------------------------------------------------------------------------
#author: Rajmund Kozuszek
#date : 2024-04-26
#description : BMP file reading and writing (1 and 4 bpp tested)
#-------------------------------------------------------------------------------

.include "img_info.asm"

.globl read_bmp
.globl save_bmp

	.text
#============================================================================
# read_bmp:
#	reads the content of a bmp file into memory
# arguments:
#	a0 - address of image descriptor structure
#		input filename pointer, header and image buffers should be set
# return value:
#	a0 - 0 if successful, error code in other cases
read_bmp:
	mv   t0, a0	# preserve imgInfo structure pointer

# open file
	li   a7, system_OpenFile
	lw   a0, ImgInfo_fname(t0)	# file name
	li   a1, 0			# flags: 0-read file
	ecall

	blt  a0, zero, rb_error
	mv   t1, a0	# save file handle for the future

# read header
	li   a7, system_ReadFile
	lw   a1, ImgInfo_hdrdat(t0)
	li   a2, BMPHeader_Size
	ecall

# extract image information from header
	lw   a0, BMPHeader_width_offset(a1)
	sw   a0, ImgInfo_width(t0)

	# compute line size in bytes - bmp line has to be multiple of 4

	# first: pixels_in_bits = width * bpp
	lhu  t2, BMPHeader_bpp_offset(a1)	# this word is not properly aligned
	sw   t2, ImgInfo_bpp(t0)
	mul  a0, a0, t2

	# last: ((pixels_in_bits + 31) / 32 ) * 4
	addi a0, a0, 31
	srai a0, a0, 5
	slli a0, a0, 2	# linebytes = ((pixels_in_bits + 31) / 32 ) * 4

	sw   a0, ImgInfo_lbytes(t0)

	lw   a0, BMPHeader_height_offset(a1)
	sw   a0, ImgInfo_height(t0)

# read lookup table data
	li   a7, system_ReadFile
	mv   a0, t1
	lw   a1, ImgInfo_hdrdat(t0)
	addi a1, a1, BMPHeader_Size
	lw   t2, ImgInfo_bpp(t0)
	li   a2, 1
	sll  a2, a2, t2
	slli a2, a2, 2
	ecall

# read image data
	li   a7, system_ReadFile
	mv   a0, t1
	lw   a1, ImgInfo_imdat(t0)
	li   a2, MAX_IMG_SIZE
	ecall

# close file
	li   a7, system_CloseFile
	mv   a0, t1
	ecall

	mv   a0, zero
	jr   ra

rb_error:
	li a0, 1	# error opening file
	jr ra

# ============================================================================
# save_bmp - saves bmp file stored in memory to a file
# arguments:
#	a0 - address of ImgInfo structure containing description of the image`
# return value:
#	a0 - zero if successful, error code in other cases

save_bmp:
	mv   t0, a0	# preserve imgInfo structure pointer

# open file
	li   a7, system_OpenFile
	lw   a0, ImgInfo_fname(t0)	#file name
    li   a1, 1	# flags: 1-write file
	ecall

	blt  a0, zero, wb_error
	mv   t1, a0	# save file handle for the future

# write header
	li   a7, system_WriteFile
	lw   a1, ImgInfo_hdrdat(t0)
	li   a2, BMPHeader_Size

# add color lookup table
	lw   t3, ImgInfo_bpp(t0)
	li   t2, 1
	sll  t2, t2, t3
	slli t2, t2, 2	# each lookup table entry has four bytes
	add  a2, a2, t2
	ecall

# write image data
	li   a7, system_WriteFile
	mv   a0, t1
# compute image size (linebytes * height)
	lw   a2, ImgInfo_lbytes(t0)
	lw   a1, ImgInfo_height(t0)
	mul  a2, a2, a1
	lw   a1, ImgInfo_imdat(t0)
	ecall

# close file
	li a7, system_CloseFile
	mv a0, t1
	ecall

	mv a0, zero
	jr ra

wb_error:
	li a0, 2 # error writing file
	jr ra
