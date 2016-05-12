open/read/write any binary file in ProDOS filesystem.
runs from any directory on floppy or hard disk.
searches the file system for the requested file, can even look inside subdirectories.
only 5 sectors long in memory (7 sectors if writing enabled).

usage:

jsr init ;one-time call to unhook ProDOS, detect drive type, and relocate code to top of memory

;open and read a file without address override or writing enabled
lda #<file_to_read
sta namlo
lda #>file_to_read
sta namhi
jsr opendir ;open and read entire file into memory at its load address

;open and read a file with address override but without writing enabled
lda #<file_to_read
sta namlo
lda #>file_to_read
sta namhi
lda #<place_to_read
sta adrlo
lda #>place_to_read
sta adrhi
jsr opendir ;open and read entire file into memory to the specified load address

;open and read a subdirectory without address override or writing enabled
lda #<dir_to_read
sta namlo
lda #>dir_to_read
sta namhi
jsr opendir ;open and read subdirectory to top of memory for later
;issue another open request to find a file inside it
lda #<file_to_read
sta namlo
lda #>file_to_read
sta namhi
jsr readdir ;read directory without opening it again

;open and read a file with writing enabled but without address override
lda #<file_to_read
sta namlo
lda #>file_to_read
sta namhi
lda #1
sta reqcmd
jsr opendir ;open and read entire file into memory at its load address

;open and write a file without address override
lda #<file_to_write
sta namlo
lda #>file_to_write
sta namhi
lda #0
sta sizelo
lda #>bytes_to_write
sta sizehi
lda #2
jsr opendir ;open and write bytes from memory to file load address

;open and write a file with address override
lda #<file_to_write
sta namlo
lda #>file_to_write
sta namhi
lda #0
sta sizelo
lda #>bytes_to_write
sta sizehi
lda #<place_to_write
sta adrlo
lda #>place_to_write
sta adrhi
lda #2
jsr opendir ;open and write bytes from memory to specified load address


format of request name is Pascal-style (length, text):
e.g. !raw 5, "MYDIR" or !raw 6, "MYFILE" or !raw 14, "QKUMBAROXURSOX"
