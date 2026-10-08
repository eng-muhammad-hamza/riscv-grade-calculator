.data
weights:        .float 5.0, 5.0, 10.0, 10.0, 30.0, 40.0     # Weight percentages
total_marks:    .word 10, 10, 100, 100, 50, 100             # Total marks for each component

input_filename:     .asciz "input.txt"
output_filename:    .asciz "output.txt"
newline:            .asciz "\n"
fail_msg:           .asciz "Failed Students:\n"
tot_msg:            .asciz "Total No of Students: "
avg_msg:            .asciz "Average Marks of Class: "
buffer:             .space 100
line_buf:           .space 100
console_buf:        .space 50
temp_buff:          .space 10
str_buff:           .space 20

num_students:       .word 0

.text
.globl _start

.macro open_file filename, flags, mode
    li a7, 56                                   # syscall: openat   ==> Used openat because Open Command is not working
    li a0, -100                                 # AT_FDCWD          ==> -100 MEANS In the Current Directory
    la a1, \filename                            # FileName          ==> FileName is the name of the file to be opened
    li a2, \flags                               # flags             ==> Flags is the open mode (O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, etc.)
    li a3, \mode                                # mode              ==> Mode is the permission bits for the file
    ecall                                       # syscall           ==> Returns the file descriptor in a0
.endm

.macro close_file fd                            # File Descriptor must be passed in fd as a REGISTER
    li a7, 57                                   # syscall: close    ==> Close the file descriptor
    mv a0, \fd                                  # file descriptor   ==> File Descriptor is the point or position where message must be written
    ecall                                       # syscall           ==> Returns 0 on success, -1 on error in a0
.endm

.macro write_content fd, msg, len               # File Descriptor must be passed in fd as a REGISTER
    li a7, 64                                   # syscall: write    ==> Write any message to the file descriptor
    mv a0, \fd                                  # file descriptor   ==> File Descriptor is the point or position where message must be written
    la a1, \msg                                 # message address   ==> Message Address is the address of the message to be written
    mv a2, \len                                 # message length    ==> Message Length is the length of the message to be written
    ecall                                       # syscall           ==> Returns the number of bytes written in a0
.endm

.macro write_content_const fd, msg, len         # File Descriptor must be passed in fd as a CONSTANT
    li a7, 64                                   # syscall: write    ==> Write any message to the file descriptor
    li a0, \fd                                  # file descriptor   ==> File Descriptor is the point or position where message must be written
    la a1, \msg                                 # message address   ==> Message Address is the address of the message to be written
    li a2, \len                                 # message length    ==> Message Length is the length of the message to be written
    ecall                                       # syscall           ==> Returns the number of bytes written in a0
.endm

.macro write_content_const_len fd, msg, len     # File Descriptor must be passed in fd as a CONSTANT but length of the string as a reg
    li a7, 64                                   # syscall: write    ==> Write any message to the file descriptor
    li a0, \fd                                  # file descriptor   ==> File Descriptor is the point or position where message must be written
    la a1, \msg                                 # message address   ==> Message Address is the address of the message to be written
    mv a2, \len                                 # message length    ==> Message Length is the length of the message to be written
    ecall                                       # syscall           ==> Returns the number of bytes written in a0
.endm

.macro read_content fd, buffer, len             # File Descriptor must be passed in fd as a REGISTER
    li a7, 63                                   # syscall: read     ==> Read any message from the file descriptor
    mv a0, \fd                                  # file descriptor   ==> File Descriptor is the point or position from where message must be read
    mv a1, \buffer                              # buffer address    ==> Buffer Address is the address of the buffer to be filled with the message
    li a2, \len                                 # buffer length     ==> Buffer Length is the length of the buffer to be read
    ecall                                       # syscall           ==> Returns the number of bytes read in a0
.endm

.macro exit_program status
    li a7, 93                                   # syscall: exit     ==> Exit the program
    li a0, \status                              # exit status code  ==> Exit Status Code is the code to be returned to the operating system to tell how program ends
    ecall                                       # syscall           ==> Returns 0 on success, -1 on error in a0
.endm

# Macro: increment_num_students
# Increments the 'num_students' variable by 1
.macro increment_num_students
    la   t0, num_students                       # Load address of num_students
    lw   t1, 0(t0)                              # Read current value
    addi t1, t1, 1                              # Increment by 1
    sw   t1, 0(t0)                              # Store back
.endm

# Read_Line_From_File Macro Gives the Following Results:
# It reads a line from the file descriptor and stores it in the buffer until a newline or null terminator is found
# OUTPUTS:
# a0 -> number of bytes read
# INPUTS:
# fd -> file descriptor (Register)
# buffer -> address of the buffer to be written (Register)
# max_size -> maximum size of the buffer to be written (Constant)
.macro read_line_from_file fd, buffer, max_size
    la a1, \buffer                              # Load buffer address
    li t0, 0                                    # Length counter
    li t3, \max_size                            # Maximum buffer size
1:
    read_content \fd, a1, 1                     # Read 1 byte from file descriptor
    blez a0, 2f                                 # If EOF or error, check for partial line
    lb t1, 0(a1)                                # Load read byte
    li t2, '\n'                                 # Newline character
    beq t1, t2, 3f                              # If newline, end this line
    li t2, 0                                    # Null terminator
    beq t1, t2, 3f                              # If null terminator, end this line
    addi t0, t0, 1                              # Increment length counter
    addi a1, a1, 1                              # Advance the buffer pointer
    blt t0, t3, 1b                              # Keep reading if buffer not full
2:
    bgtz t0, 3f                                 # If we have read some data, go to end means if t0 > 0 then go to 3
    j close_files_and_exit                      # If no data read, close files and exit
3:
    sb zero, 0(a1)                              # Null-terminate
    mv a0, t0                                   # Length of the line read
    increment_num_students                      # Increment the number of students
.endm

# Extract_Info_Till_Delimiter Macro gives the following results:
# It extracts the information from the input buffer till a space or newline or null terminator is found
# Inputs:
# from_read_buffer -> input buffer
# frb_counter -> counter for the input buffer
# to_place_buffer -> output buffer
# tpb_counter -> counter for the output buffer
# Outputs:
# from_read_buffer -> updated input buffer
# frb_counter -> updated counter for the input buffer
# to_place_buffer -> updated output buffer
# tpb_counter -> updated counter for the output buffer
.macro extract_info_till_delimiter from_read_buffer, frb_counter, to_place_buffer, tpb_counter
1:
    lb t0, 0(\from_read_buffer)                     # Load byte from input buffer
    addi \from_read_buffer, \from_read_buffer, 1    # Advance input buffer pointer
    addi \frb_counter, \frb_counter, 1          # Advance input buffer counter
    li t1, ' '
    beq t0, t1, 2f                              # If byte == space, end
    beqz t0, 2f                                 # If byte == 0, end
    li t1, '\n'                                 # Load newline character
    beq t0, t1, 2f                              # If byte == newline, end
    sb t0, 0(\to_place_buffer)                  # Store into output buffer
    addi \to_place_buffer, \to_place_buffer, 1  # Advance output buffer pointer
    addi \tpb_counter, \tpb_counter, 1          # Advance outpu buffer counter
    j 1b                                        # Loop back to read next byte
2:
.endm

# Append Character Macro gives the following results:
# I just adds the character to the output buffer and increments the output buffer pointer and counter
# Inputs:
# to_place_buffer -> output buffer
# tpb_counter -> counter for the output buffer
# character -> character to be appended
# Outputs:
# to_place_buffer -> updated output buffer
# tpb_counter -> updated counter for the output buffer
.macro append_character_to_buffer to_place_buffer, tpb_counter, character
    li t0, \character                           # Loading the Character into a temp register
    sb t0, 0(\to_place_buffer)                  # Store space in the output buffer
    addi \to_place_buffer, \to_place_buffer, 1  # Advance output buffer pointer
    addi \tpb_counter, \tpb_counter, 1          # Advance output buffer counter
.endm

# Convert Integer to String Macro gives the following results:
# It converts an integer to a string and stores it in the buffer
# Inputs:
# integer -> integer to be converted
# buffer -> address of the buffer to store the string
# Outputs:
# buffer -> updated buffer with the string representation of the integer
# a3 -> length of the string
.macro itoa integer, buffer
    mv a0, \integer                 # Load the integer to convert into a0
    la a2, \buffer                  # a2 = Start of buffer
    li a3, 0                        # a3 = Character count
    li t0, 10                       # Base 10
    li t1, 0                        # Sign flag
    bgez a0, 1f                     # if a0 >= 0, skip negation, means the number is positive
    li t1, 1                        # Set Sign Flag to make the string representation with '-'
    neg a0, a0                      # Make the negative number Positive for easy conversion

1:
    mv t2, a0                       # Copy input value to t2, so that original value don't gets modified
    beqz t2, 6f                     # If the number itself is zero, write '0' directly

# The extract digits logic is working as follows:
# 1. We take the number and divide it by 10, which gives us the quotient and remainder.
# -- The remainder is the last digit of the number.
# 2. We convert the remainder to its ASCII representation by adding '0' (48 in decimal).
# 3. We store the ASCII character in the buffer.
# 4. We repeat this process until the number becomes zero.
# 5. If the number was negative, we add a '-' sign at the end.
# -- This is filling up the buffer in reverse order.
# 6. Finally, we reverse the string to get the correct order.
# 7. We add a null terminator at the end of the string.
2:
    rem t3, t2, t0                  # t3 = t2 % 10 -- Extracting the last digit
    div t2, t2, t0                  # t2 = t2 / 10 -- Extracting the remaining number
    addi t3, t3, '0'                # Converting the last digit to ASCII
    sb t3, 0(a2)                    # Storing digit in the buffer
    addi a2, a2, 1                  # Incrementing the buffer
    addi a3, a3, 1                  # Incrementing the Character Count
    bnez t2, 2b                     # if t2 != 0 -- Means there are more remaining digits
    beqz t1, 3f                     # if t1 == 0 -- Means the sign flag is not high then the number is positive
                                    # Otherwise handle the negative sign
    li t3, '-'                      # Loading the Negative Sign
    sb t3, 0(a2)                    # Storing the negative Sign at the end of buffer
    addi a2, a2, 1                  # Incrementing the buffer
    addi a3, a3, 1                  # Incrementing the Character Count

3:
    sb zero, 0(a2)                  # Null terminate the string buffer

    # We have now Extracted the number in reverse order so reversing the whole string.

    la t0, \buffer                  # Loading String Buffer in temporary register
    addi t1, a3, -1                 # t1 = last character index (before '\0')

4:
    ble t1, zero, 5f                # if t1 <= 0, we are done
    add t2, t0, t1                  # t2 = index of character specified by t1
    lbu t3, 0(t0)                   # load start Character
    lbu t4, 0(t2)                   # load end Character
    sb t4, 0(t0)                    # Store end character at start position
    sb t3, 0(t2)                    # Store start character at end position
    addi t0, t0, 1                  # Move start pointer to right
    addi t1, t1, -2                 # Decrement the last character index by 2
    j 4b

5:
    la a2, str_buff                 # Reset a2 to point to the start of the string
    j 7f

6:
    li t3, '0'                      # If the number is zero, write '0'
    sb t3, 0(a2)                    # Store '0' in the buffer
    addi a2, a2, 1                  # Increment the buffer pointer
    li a3, 1                        # Set length to 1 (for '0')
    sb zero, 0(a2)                  # Null terminate the string
    j 7f
7:
.endm

# Convert String to Integer Macro gives the following results:
# It converts a string to an integer and stores it in the integer variable
# Inputs:
# buffer -> address of the string to convert
# integer -> Register of the integer variable to store the result
# Outputs:
# integer -> updated integer variable with the converted value
.macro atoi buffer, integer
    la a1, \buffer                  # Load address of the string to convert
    li a0, 0                        # Result accumulator
    li t0, 10                       # Base 10
    li t1, 0                        # Sign flag

    lbu t2, 0(a1)                   # Load first char
    li t3, '-'                      # Check for negative sign
    bne t2, t3, 1f                  # If not '-', continue parsing
    li t1, 1                        # Set sign flag
    addi a1, a1, 1                  # Skip '-' for now for easy parsing

1:
    lbu t2, 0(a1)                   # Load char
    beqz t2, 2f                     # Stop only at null terminator
    
    li t3, '0'                      # Check for '0'
    blt t2, t3, 2f                  # If less than '0', stop parsing
    li t3, '9'                      # Check for '9'
    bgt t2, t3, 2f                  # If greater than '9', stop parsing
    
    addi t2, t2, -48                # Convert ASCII to integer
    mul a0, a0, t0                  # Multiply current result by 10
    add a0, a0, t2                  # Add the new digit to the result
    addi a1, a1, 1                  # Next char
    j 1b

2:
    beqz t1, 3f                     # If sign flag is 0, means the number is positive, return the result
    neg a0, a0                      # If sign flag is 1, means the number is negative, negate the result
    mv a0, \integer                 # Store the result in the integer variable register
3:
.endm

_start:

    la sp, stack_end                            # Initialize stack pointer

    open_file input_filename, 0, 0              # Open the input file with read and create permissions
    blt a0, zero, exit_error                    # Check if file opened successfully
    mv s0, a0                                   # Save file descriptor for input file

    open_file output_filename, 577, 0644        # Open the output file with read and create permissions
    blt a0, zero, close_files_and_exit          # Check if file opened successfully
    mv s1, a0                                   # Save file descriptor for output file

    fcvt.s.w fs1, zero                          # Convert integer 0 to float 0.0, initializing a floating point register for average calculation

    write_content_const 1, fail_msg, 17         # Write the fail message to Console, done here to avoid writing it multiple times

read_line:
    read_line_from_file s0, buffer, 100         # Read a line from the input file
    la s6, buffer                               # Loading buffer address
    li s5, 0                                    # Initialize buffer counter
    la s4, line_buf                             # Loading output buffer address
    li s3, 0                                    # Initialize output buffer counter
    extract_info_till_delimiter s6, s5, s4, s3  # Extract first name
    append_character_to_buffer s4, s3, ' '      # Append space after first name
    extract_info_till_delimiter s6, s5, s4, s3  # Extract Second name
    append_character_to_buffer s4, s3, ' '      # Append space after Second name
    extract_info_till_delimiter s6, s5, s4, s3  # Extract Roll No
    append_character_to_buffer s4, s3, ' '      # Append space after roll no
    addi sp, sp, -8
    sw s3, 0(sp)                                # Save length of line buffer
    sw s4, 4(sp)                                # Save address of line buffer

    fcvt.s.w fs0, zero                          # Convert integer 0 to float 0.0, initializing a floating point register

    li t5, 0                                    # t0 = initial offset
    li t6, 6                                    # t1 = max number of fields to process (quiz1, quiz2, assign1, assign2, midterm, final)

process_loop:
    la s4, temp_buff                            # Load address of temp_buff
    li s3, 0                                    # Reset s3 = 0
    extract_info_till_delimiter s6, s5, s4, s3  # Extract info into temp_buff
    sb zero, 0(s4)                              # Null-terminate temp_buff

    la a1, temp_buff                            # Load address of the string from which marks are to be extracted
    atoi temp_buff, a0                          # Convert string to integer
    blt a0, zero, close_files_and_exit          # Check if conversion was successful
    fcvt.s.w f1, a0                             # Convert integer marks to float
    la t2, weights                              # Load weights array address
    mv a2, t5                                   # Load weights array offset
    add t2, t2, a2                              # Advance weights array to the correct field
    flw f2, 0(t2)                               # Load weight for the current field
    la t3, total_marks                          # Load total marks array address
    mv a3, t5                                   # Load total marks array offset
    add t3, t3, a3                              # Advance total marks array to the correct field
    lw t4, 0(t3)                                # Load total marks for the current field
    fcvt.s.w f3, t4                             # Convert total marks to float
    fdiv.s f4, f1, f3                           # f4 = marks / total
    fmul.s f4, f4, f2                           # f4 = (marks / total) * weight
    fadd.s fs0, fs0, f4                         # Add to total obtained marks
    
    addi t5, t5, 4                              # t5 = t5 + 4 (move to next offset)
    addi t6, t6, -1                             # t6 = t6 - 1 (decrement field count)
    bnez t6, process_loop                       # If t6 != 0, repeat

    fadd.s fs1, fs1, fs0                        # Add the total obtained marks to the average

    fcvt.w.s a0, fs0, rne                       # a0 = Rounded value of fs0 means the weighted total obtained marks

    addi s6, a0, 0                              # Store weighted total in s6 for further processing
    itoa a0, str_buff                           # Convert the weighted total to string and store in str_buff
    lw s4, 4(sp)                                # Restore the address of the line buffer
    lw s5, 0(sp)                                # Restore the length of the line buffer
    addi sp, sp, 8                              # Restore stack pointer

    la s2, str_buff                             # Load the string buffer address
    li s3, 0                                    # Initialize the counter for the string buffer
    extract_info_till_delimiter s2, s3, s4, s5  # Extracting the weightage marks from str_buff and place it to output buff
    append_character_to_buffer s4, s5, ' '      # Add the space to the output buffer

    li t4, 80                                   # Conditions for grade 'A'
    bge s6, t4, grade_A                         # Check if grade is 'A'
    li t4, 70                                   # Conditions for grade 'B'
    bge s6, t4, grade_B                         # Check if grade is 'B'
    li t4, 60                                   # Conditions for grade 'C'
    bge s6, t4, grade_C                         # Check if grade is 'C'
    li t4, 50                                   # Conditions for grade 'D'
    bge s6, t4, grade_D                         # Check if grade is 'D'
    append_character_to_buffer s4, s5, 'F'      # Add the grade character to the output buffer
    li s6, 'F';                                 # Store grade in s6 for further processing
    j grade_done

grade_A:
    append_character_to_buffer s4, s5, 'A'      # Add the grade character to the output buffer
    li s6, 'A';                                 # Store grade in s6 for further processing
    j grade_done
grade_B:
    append_character_to_buffer s4, s5, 'B'      # Add the grade character to the output buffer
    li s6, 'B';                                 # Store grade in s6 for further processing
    j grade_done
grade_C:
    append_character_to_buffer s4, s5, 'C'      # Add the grade character to the output buffer
    li s6, 'C';                                 # Store grade in s6 for further processing
    j grade_done
grade_D:
    append_character_to_buffer s4, s5, 'D'      # Add the grade character to the output buffer
    li s6, 'D';                                 # Store grade in s6 for further processing
    j grade_done

grade_done:
    append_character_to_buffer s4, s5, '\n'     # Add the newline character to the output buffer

    li t0, 'F'                                  # Check if grade is 'F'
    bne s6, t0, write_output                    # If not 'F', skip writing to output

    la s2, console_buf                          # Load the console buffer address
    li s3, 0                                    # Initialize the counter for the console buffer
    la s4, buffer                               # Load the buffer address
    li s6, 0                                    # Initialize the counter for the buffer
    extract_info_till_delimiter s4, s6, s2, s3  # Extracting the first name from buffer and place it to console buffer
    append_character_to_buffer s2, s3, ' '      # Add the space to the console buffer
    extract_info_till_delimiter s4, s6, s2, s3  # Extracting the second name from buffer and place it to console buffer
    append_character_to_buffer s2, s3, ' '      # Add the space to the console buffer
    extract_info_till_delimiter s4, s6, s2, s3  # Extracting the roll number from buffer and place it to console buffer
    append_character_to_buffer s2, s3, '\n'     # Add the newline to the console buffer

    write_content_const_len 1, console_buf, s3  # Write the contents of the console buffer to the console
write_output:
    write_content s1, line_buf, s5              # Write the contents of the line buffer to the output file

    j read_line                                 # Read next line

close_files_and_exit:
    # Now Calculating the average of the students
    la t0, num_students                         # Load address of num_students
    lw s2, 0(t0)                                # Read current value
    itoa s2, str_buff                           # Convert the number of students to string and store in str_buff
    write_content_const 1, tot_msg, 22          # Write the total number of students message to Console
    write_content_const_len 1, str_buff, a3     # Write the number of students to Console
    write_content_const 1, newline, 1           # Write a newline to Console

    fcvt.s.w ft0, s2                            # Convert integer to float
    fdiv.s fs1, fs1, ft0                        # Divide the total obtained marks by number of students
    fcvt.w.s a0, fs1, rne                       # Convert the average to integer
    itoa a0, str_buff                           # Convert the average to string and store in str_buff
    mv s7, a3                                   # Store the length of the average string in s7 for further processing
    write_content_const 1, avg_msg, 24          # Write the average message to Console
    write_content_const_len 1, str_buff, s7     # Write the average value to Console
    write_content_const 1, newline, 1           # Write a newline to Console
    li t0, 24                                   # Load the length of the average message
    write_content s1, avg_msg, t0               # Write the average message to the output file
    write_content s1, str_buff, s7              # Write the average value to the output file
    li t0, 1                                    # Load the length of the newline
    write_content s1, newline, t0               # Write a newline to the output file

    close_file s0                               # Close the input file descriptor
    close_file s1                               # Close the output file descriptor
    exit_program 0                              # Exit the program with success status
exit_error:
    exit_program 1                              # Exit the program with error status

.bss
.align 2
stack_start: .space 128                         # Stack space for local variables
stack_end:

