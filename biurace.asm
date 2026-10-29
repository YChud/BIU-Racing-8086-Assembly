;Course: Microprocessors and Assembly Language (83255-01), Bar Ilan University
;Lecturer: Prof. Ran Gelles
;Semester: Spring Semester 2026 
;Submitted by: Yonatan Chudnoff
;Title: BIU Racing: The Game
;Description: Retro racing game using the mouse, keyboard, interrupts and RTC

.model small
.stack 100h
.data
	
	;welcome screen
	Screen_First_Position DW 0h
	Welcome_Screen_Message DB 'Welcome to $'
	Biu_Racing_Message DB 'BIU RACING: The Game $'
	Bgu_Racing_Message DB 'BGU RACING: The Game $'
	Copyright_Message DB '(C) 2026 Chud Games$'
	Press_Start_Message DB 'PRESS START$'
	Start_Click DB 0d
	
	;cheat codes
	Cheats_Intro DB 'Have Cheat Codes? (y/n):$'
	Cheats_Availability DB 0d
	Cheats_Enter_Message DB 'Enter Cheat Code and Press Enter:$'
	Cheats_Correct DB 0d
	
	;game over screen
	Game_Over_Message DB 'GAME OVER$'
	Play_Again_Message DB 'Play Again?$'
	Yes_Message DB 'Yes$'
	No_Message DB 'No$'
	Play_Again_Click DB 2d
	
	;player car attributes
	Player_Position DW 0C2Eh
	Player_Position2 DW 0CCCh
	Player_Position4 DW 0CD0h
	Player_Position6 DW 0E0Ch
	Player_Position8 DW 0E10h
	Player_Position9 DW 0EAAh
	Player_Position13 DW 0EB2h
	Player_Direction DB 0d
	Player_Color DW 0A020h
	
	;enemy car attributes
	Enemy_Position DW 32h
	Enemy_Position6 DW 210h 
	Enemy_Position8 DW 214h
	Enemy_Position9 DW 2AEh
	Enemy_Position10 DW 2B0h
	Enemy_Position11 DW 2B2h
	Enemy_Position12 DW 2B4h
	Enemy_Position13 DW 2B6h
	Enemy_Color DW 4020h
	Enemy_Color_Selection DW 1 dup (1020h, 2020h, 4020h, 5020h, 6020h)
	
	;variables for timer
	Ticker DW 0d
	Enemy_Move_Flag DB 0d
	
	;variables for DrawCar function
	DrawCar_Car_Choice DB 0d
	DrawCar_Car_Color DW 0A020h
	DrawCar_Car_Position DW 0C2Eh
	
	;variables for collision detection
	Is_Collision DB 0d
	Left_Wall DW 0E84h
	Right_Wall DW 0ED8h
	
	;enemy generation
	Left_Lane_Position DW 32h
	Middle_Lane_Position DW 4Eh
	Right_Lane_Position DW 6Ah
	Seconds DW 0d
	
	;global color variables
	Black_Color DW 0020h
	Green_Color DW 2020h
	Cyan_Color DW 3020h
	Red_Color DW 4020h
	Brown_Color DW 6020h
	Grey_Color DW 7020h
	White_Color DW 0F23h
	Yellow_Lane_Color DW 7E23h
	Desert_Color DW 6E23h
	Color_Offset DW 0d
	
	;variables for score appearance and calculation
	Score_Message DB 'Score:$'
	Score DW 0d
	Score_Adder DW 1d
	Score_Final_Tens DB 0h
	Score_Final_Ones DB 0h
	
	;variables for speed appearance
	Speed_25_Message DB 'Speed:  25 km/h$'
	Speed_50_Message DB 'Speed:  50 km/h$'
	Speed_75_Message DB 'Speed:  75 km/h$'
	Speed_100_Message DB 'Speed: 100 km/h$'
	Speed_125_Message DB 'Speed: 125 km/h$'
	Speed_Level DB 1d
	
	;variables for score overflow
	Is_Score_Overflow DB 0d
	Score_Overflow_Message1 DB 'Score: Overflow $'
	Score_Overflow_Message2 DB 'Speed:level 256$'

.code

;===========================================================
;							Macros
;===========================================================

;***********************************************************
;							MoveCursor
;job: moves cursor to the given x,y position
;inputs: x,y (in hex)
;outputs: none
;***********************************************************
MoveCursor MACRO x,y

	mov dl, x
	mov dh, y
	mov bh, 00h
	mov ah, 02h
	int 10h

ENDM


;***********************************************************
;							TextConvert
;job: converts pixel mode coordinate to be text mode coordinate
;inputs: reg which is in pixel coordinate
;outputs: reg in text mode coordinate
;***********************************************************
TextConvert MACRO reg

	shr reg, 1
	shr reg, 1
	shr reg, 1

ENDM


;***********************************************************
;							CarToDraw
;job: chooses which car to draw
;inputs: 0 for player and 1 for enemy
;outputs: value stored in DrawCar_Car_Choice
;***********************************************************
CarToDraw MACRO ZeroForPlayerOneForEnemy

	mov al, ZeroForPlayerOneForEnemy
	mov DrawCar_Car_Choice, al

ENDM


;***********************************************************
;							CollisionWith
;job: checks if two positions are equal
;inputs: FirstItem SecondItem
;outputs: jumps to CheckCollisionRaiseFlag if positions are equal
;***********************************************************
CollisionWith MACRO FirstItem, SecondItem

	mov bx, FirstItem
	mov dx, SecondItem
	cmp bx, dx
	
	je CheckCollisionRaiseFlag
	
ENDM



;===========================================================
;							Interrupt Handling
;===========================================================

;***********************************************************
;							ISR_New_int8
;job: timer interrupt handler
;inputs: Ticker
;outputs: Ticker
;***********************************************************
ISR_New_int8 PROC far uses ax es

	;increase Ticker by 1 on each timer interrupt
	mov ax, Ticker
	add ax, 1d
	mov Ticker, ax
	
	;call the original int 8 saved at 84h
	prev_int8:
		int 84h

	iret
ISR_New_int8 ENDP


;***********************************************************
;							ISR_New_int9
;job: keyboard interrupt handler for player movement and speed
;inputs: relevant keyboard scan codes
;outputs: Player_Direction, Speed_Level
;***********************************************************
ISR_New_int9 PROC far uses ax es
	
		;read the keyboard scan code from port 60h
		in al, 60h
		
		;see if Left key was pushed
		cmp al, 4Bh
		je PressLeft
		
		;see if Right key was pushed
		cmp al, 4Dh
		je PressRight
		
		;see if "f" key was pushed
		cmp al, 21h
		je PressF
		
		;see if "s" key was pushed
		cmp al, 1Fh
		je PressS
		
		;if no relevant key pressed go back to original instructions
		jmp prev_int9
		
		;command for Left being pushed
		PressLeft:
			mov al, 2d
			mov Player_Direction, al
			jmp prev_int9
	
		;command for Right being pushed
		PressRight:
			mov al, 1d
			mov Player_Direction, al
			jmp prev_int9
			
		;Command for "f" being pushed
		PressF:
			;makes sure you can't get above 5 for speed level
			mov al, Speed_Level
			cmp al, 5d
			je prev_int9
			
			;if less than 5 then add 1 to Speed_Level
			add al, 1d
			mov Speed_Level, al
			jmp prev_int9
	
		;Command for "s" being pushed
		PressS:
			;makes sure you can't get below 1 for speed level
			mov al, Speed_Level
			cmp al, 1d
			je prev_int9
			
			;if greater than 1 then subtract 1 from Speed_Level
			sub al, 1d
			mov Speed_Level, al
			jmp prev_int9
	
		;call original int 9 handler
		prev_int9:
			int 80h
			
			
		
		iret
ISR_New_int9 ENDP
	


;===========================================================
;							Functions
;===========================================================

;Menu/Screen Functions

;***********************************************************
;							PrintWelcomeScreen
;job: prints welcome screen and press start message
;inputs: Cheats_Correct
;outputs: screen displays opening messages
;		  opening messages vary if correct cheat code entered
;***********************************************************
PrintWelcomeScreen PROC

	;print the Welcome message
	MoveCursor 22h, 2h
	mov dx, OFFSET Welcome_Screen_Message
	mov ah, 09h
	int 21h
	
	
	;check which message to print cheat or no cheat
	mov al, Cheats_Correct
	cmp al, 1d
	je BGUPrint
	
	;print the BIU Racing message
	MoveCursor 1Dh, 4h
	mov dx, OFFSET Biu_Racing_Message
	mov ah, 09h
	int 21h
	jmp CopyrightPrint
	
	
	BGUPrint:
		;print the BGU Racing message
		MoveCursor 1Dh, 4h
		mov dx, OFFSET Bgu_Racing_Message
		mov ah, 09h
		int 21h
	
	
	CopyrightPrint:
		;print the copyright message
		MoveCursor 1Eh, 17h
		mov dx, OFFSET Copyright_Message
		mov ah, 09h
		int 21h
	
	;print the Press Start message
	MoveCursor 22h, 0Dh
	mov dx, OFFSET Press_Start_Message
	mov ah, 09h
	int 21h

	ret
PrintWelcomeScreen ENDP


;***********************************************************
;							CheckForStartClick
;job: checks if the PRESS START was clicked
;inputs: mouse click and mouse position
;outputs: Start_Click
;***********************************************************
CheckForStartClick PROC

	;receive mouse click information
	mov ax, 03h
	int 33h
	
	;first check if the left mouse button was clicked
	cmp bx, 01h
	jne FinishCheckForStartClick
	
	;convert pixel position to text mode position
	;cx is the x position the columns
	TextConvert cx
	
	;dx is the y position the rows
	TextConvert dx
	
	;check if the row matches the clickable option rows
	cmp dx, 0Dh
	jne FinishCheckForStartClick
	
	;now check if the click is in the range of the "PRESS START" (columns)
	;first we check the left range
	CheckLeftStart:
		cmp cx, 22h
		jge CheckRightStart
		jmp FinishCheckForStartClick
	
	;check the right range		
	CheckRightStart:
		cmp cx, 2Ch
		jle StartHasBeenClicked
		jmp FinishCheckForStartClick
		
	;raise the flag that PRESS START has been clicked
	StartHasBeenClicked:
		mov al, 1d
		mov Start_Click, al
	
	;finish function		
	FinishCheckForStartClick:
		ret
CheckForStartClick ENDP
	

;***********************************************************
;							CheckCheats
;job: checks if the user has a cheat code to enter
;inputs: keyboard input
;outputs: Cheats_Availability
;***********************************************************
CheckCheats PROC

	;moves the cursor to print where press start was
	MoveCursor 1Bh,0Dh
	
	;ask if have cheat codes
	mov dx, OFFSET Cheats_Intro
	mov ah, 09h
	int 21h
	
	;wait for user response
	mov ah, 01h
	int 21h
	
	;see if No (n) was put in
	mov dl, 6Eh
	cmp al, dl
	je NoCheat
	
	;see if Yes (y) was put in
	mov dl, 79h
	cmp al, dl
	je YesCheat
	
	;if invalid input
	jmp InvalidCheat
	
	
	;enters different values into the Cheats_Availability flag
	;per user answer
	NoCheat:
	
		mov al, 0d
		mov Cheats_Availability, al
		jmp FinishCheckCheats
		
	YesCheat:
		
		mov al, 1d
		mov Cheats_Availability, al
		jmp FinishCheckCheats
	
	InvalidCheat:
		mov al, 2d
		mov Cheats_Availability, al
		
	;finish function	
	FinishCheckCheats:
	ret
	
CheckCheats ENDP


;***********************************************************
;							VerifyCheatCode
;job: checks if the entered code is correct
;inputs: keyboard input
;outputs: Cheats_Correct
;***********************************************************
VerifyCheatCode PROC

	;push into the stack the cheat code characters
	;start with the enter key
	mov ax, 0Dh
	push ax
	
	;next push the "u"
	mov ax, 75h
	push ax
	
	;next push the "g"
	mov ax, 67h
	push ax
	
	;next push the "b"
	mov ax, 62h
	push ax
	
	
	;now we print the enter cheat prompt
	MoveCursor 16h, 10h
	mov dx, OFFSET Cheats_Enter_Message
	mov ah, 09h
	int 21h
	
	
	;check first letter "b"
	CodeLetter1:
		;read the next character from the user
		mov ah, 01h
		int 21h
		
		;pop expected charcater from the stack into dx
		pop dx
		cmp al, dl
		je CodeLetter2
		
		;we need to clean the rest of the stack if the code is wrong
		pop ax
		pop ax
		pop ax
		jmp FinishVerifyCheatCode
	
	
	;check second letter "g"
	CodeLetter2:
		;read the next character from the user
		mov ah, 01h
		int 21h
		
		;pop expected charcater from the stack into dx
		pop dx
		cmp al, dl
		je CodeLetter3
		
		;we need to clean the rest of the stack if the code is wrong
		pop ax
		pop ax
		jmp FinishVerifyCheatCode
		
		
	;check third letter "u"
	CodeLetter3:
		;read the next character from the user
		mov ah, 01h
		int 21h
		
		;pop expected charcater from the stack into dx
		pop dx
		cmp al, dl
		je CodeLetter4
		
		;we need to clean the rest of the stack if the code is wrong
		pop ax
		jmp FinishVerifyCheatCode

	;check if Enter is pushed
	CodeLetter4:
		;read the next character from the user
		mov ah, 01h
		int 21h
		
		;pop expected charcater from the stack into dx
		pop dx
		cmp al, dl
		jne FinishVerifyCheatCode
		
	;it will only get to this part if the code is correct
	CorrectCodeEntered:
		
		;raise the Cheats_Correct flag
		mov al, 1d
		mov Cheats_Correct, al


	;finish function
	FinishVerifyCheatCode:
	
	ret
VerifyCheatCode ENDP


;***********************************************************
;							PrintGameOverScreen
;job: prints the game over and play again screen
;inputs: none
;outputs: screen displays updated messages
;***********************************************************
PrintGameOverScreen PROC

	;game over message
	MoveCursor 23h, 0Ah
	mov dx, OFFSET Game_Over_Message
	mov ah, 09h
	int 21h
	
	;play again message
	MoveCursor 22h, 0Fh
	mov dx, OFFSET Play_Again_Message
	mov ah, 09h
	int 21h
	
	;yes message
	MoveCursor 23h, 11h
	mov dx, OFFSET Yes_Message
	mov ah, 09h
	int 21h
	
	;no message
	MoveCursor 2Ah, 11h
	mov dx, OFFSET No_Message
	mov ah, 09h
	int 21h
	

	ret
PrintGameOverScreen ENDP


;***********************************************************
;							CheckForPlayAgain
;job: checks if yes or no was clicked at play again part
;inputs: mouse click and mouse position
;outputs: Play_Again_Click
;***********************************************************
CheckForPlayAgain PROC

	;receive mouse click information
	mov ax, 03h
	int 33h
	
	;first check if the left mouse button was clicked
	cmp bx, 01h
	jne FinishCheckForPlayAgain
	
	;convert pixel position to text mode position
	;cx is the x position the columns
	TextConvert cx
	
	;dx is the y position the rows
	TextConvert dx
	
	;check if the row matches the clickable option rows
	cmp dx, 11h
	jne FinishCheckForPlayAgain
	
	;now check if the click is in the range of the "Yes" (columns)
	;first we check the left range
	CheckLeftYes:
		cmp cx, 23h
		jge CheckRightYes
		jmp FinishCheckForPlayAgain
		
	;check the right range
	CheckRightYes:
		cmp cx, 25h
		jle YesHasBeenClicked
		jmp CheckLeftNo
		
	;Now check if the click is in the range of the "no" (columns)
	;first we check the left range
	CheckLeftNo:
		cmp cx, 2Ah
		jge CheckRightNo
		jmp FinishCheckForPlayAgain
	
	;check the right range
	CheckRightNo:
		cmp cx, 2Bh
		jle NoHasBeenClicked
		jmp FinishCheckForPlayAgain
		
	;raises the flag if yes was clicked (1d)
	YesHasBeenClicked:
		mov al, 1d
		mov Play_Again_Click, al
		jmp FinishCheckForPlayAgain
		
	;set Play_Again_Click to 0 if no was clicked
	NoHasBeenClicked:
		mov al, 0d
		mov Play_Again_Click, al

	;finish function
	FinishCheckForPlayAgain:

	ret
CheckForPlayAgain ENDP


;***********************************************************
;							ScoreOverflow
;job: print score overflow messages
;inputs: none
;outputs: special overflow messages printed
;***********************************************************
ScoreOverflow PROC
	
	;print score overflow message
	MoveCursor 1h, 0h
	mov dx, OFFSET Score_Overflow_Message1
	mov ah, 09h
	int 21h
	
	;print speed overflow message
	MoveCursor 3Fh, 0h
	mov dx, OFFSET Score_Overflow_Message2
	mov ah, 09h
	int 21h

	ret
ScoreOverflow ENDP


;Game State/score Functions

;***********************************************************
;							ResetGame
;job: resets all game variables for new game
;inputs: none
;outputs: Player_Position, Is_Collision, Play_Again_Click,
;			Player_Direction, Score, Speed_Level
;***********************************************************
ResetGame PROC

	;reset player to middle lane position
	mov ax, 0C2Eh
	mov Player_Position, ax
	
	;reset all the player positions
	call UpdatePlayerPositions
	
	;reset Is_Collision to 0d
	mov al, 0d
	mov Is_Collision, al
	
	;reset the Play_Again_Click flag so it doesn't go to that again
	mov al, 2d
	mov Play_Again_Click, al
	
	;reset the direction
	mov al, 0d
	mov Player_Direction, al
	
	;reset the score
	mov ax, 0h
	mov Score, ax
	
	;reset the Speed
	mov al, 1d
	mov Speed_Level, al
	
	;reset Score Overflow
	mov al, 0d
	mov Is_Score_Overflow, al


	ret
ResetGame ENDP


;***********************************************************
;							UpdateScore
;job: converts score to printable form and prints score
;inputs: Score
;outputs: Score_Final_Ones, Score_Final_Tens
;***********************************************************
UpdateScore PROC

	;divide the score by 10 to separate the tens and ones digits
	mov ax, Score
	mov bl, 10d
	div bl
	
	;al contains tens and ah contains ones
	mov Score_Final_Tens, al
	mov Score_Final_Ones, ah
	
	;print "Score: "
	MoveCursor 5h, 0h
	mov dx, OFFSET Score_Message
	mov ah, 09h
	int 21h
	
	;convert and print the tens digit as ASCII
	mov dl, Score_Final_Tens
	add dl, 30h
	mov ah, 02h
	int 21h
	
	;convert and print the ones digit as ASCII
	mov dl, Score_Final_Ones
	add dl, 30h
	mov ah, 02h
	int 21h
	
	
	ret
UpdateScore ENDP


;***********************************************************
;							CheckScoreOverflow
;job: checks if score has reached overflow limit
;inputs: Score
;outputs: Is_Score_Overflow
;***********************************************************
CheckScoreOverflow PROC

	;sees if score is greater than 99
	mov ax, Score
	cmp ax, 99d
	jg YesScoreOverflow
	jmp FinishCheckScoreOverflow
	
	YesScoreOverflow:
		;raise Is_Score_Overflow flag
		mov al, 1d
		mov Is_Score_Overflow, al
		
	;finish function	
	FinishCheckScoreOverflow:

	ret
CheckScoreOverflow ENDP


;***********************************************************
;							UpdateScoreAdder
;job: sets points to add according to speed level
;inputs: Speed_Level
;outputs: Score_Adder
;***********************************************************
UpdateScoreAdder PROC
	
	;move Speed_Level to al to check what value it has
	mov al, Speed_Level

	;see if it's on the first gear
	cmp al, 1d
	je FirstGearPoints
	
	;see if it's on the second gear
	cmp al, 2d
	je SecondGearPoints
	
	;see if it's on the third gear
	cmp al, 3d
	je ThirdGearPoints
	
	;see if it's on the fourth gear
	cmp al, 4d
	je FourthGearPoints
	
	;see if it's on the fifth gear
	cmp al, 5d
	je FifthGearPoints
	
	;according with the speed level it changes the Score_Adder
	FirstGearPoints:
		mov ax, 1d
		mov Score_Adder, ax
		jmp FinishUpdateScoreAdder
	
	SecondGearPoints:
		mov ax, 2d
		mov Score_Adder, ax
		jmp FinishUpdateScoreAdder
		
	ThirdGearPoints:
		mov ax, 3d
		mov Score_Adder, ax
		jmp FinishUpdateScoreAdder
	
	FourthGearPoints:
		mov ax, 4d
		mov Score_Adder, ax
		jmp FinishUpdateScoreAdder
		
	FifthGearPoints:
		mov ax, 5d
		mov Score_Adder, ax
	
	;finish function
	FinishUpdateScoreAdder:

	ret
UpdateScoreAdder ENDP


;***********************************************************
;							UpdateSpeed
;job: prints the relevant speed according to the speed level
;inputs: Speed_Level
;outputs: updated speed appears on screen
;***********************************************************
UpdateSpeed PROC

	;sets the cursor to appropriate location
	MoveCursor 3Fh, 0h
	mov al, Speed_Level
	
	;select message according to speed level
	;see if it's on the first gear
	cmp al, 1d
	je FirstGear
	
	;see if it's on the second gear
	cmp al, 2d
	je SecondGear
	
	;see if it's on the third gear
	cmp al, 3d
	je ThirdGear
	
	;see if it's on the fourth gear
	cmp al, 4d
	je FourthGear
	
	;see if it's on the fifth gear
	cmp al, 5d
	je FifthGear
	
	;print 25 km/h
	FirstGear:
		mov dx, OFFSET Speed_25_Message
		mov ah, 09h
		int 21h
		jmp FinishUpdateSpeed
		
	;print 50 km/h
	SecondGear:
		mov dx, OFFSET Speed_50_Message
		mov ah, 09h
		int 21h
		jmp FinishUpdateSpeed
		
	;print 75 km/h
	ThirdGear:
		mov dx, OFFSET Speed_75_Message
		mov ah, 09h
		int 21h
		jmp FinishUpdateSpeed	

	;print 100 km/h
	FourthGear:
		mov dx, OFFSET Speed_100_Message
		mov ah, 09h
		int 21h
		jmp FinishUpdateSpeed
		
	;print 125 km/h
	FifthGear:
		mov dx, OFFSET Speed_125_Message
		mov ah, 09h
		int 21h
		jmp FinishUpdateSpeed
	
	;finish function
	FinishUpdateSpeed:

	ret
UpdateSpeed ENDP


;Timing Functions

;***********************************************************
;							CheckTicker
;job: checks if enough timer ticks passed to move enemy
;	  using different speeds
;inputs: Ticker, Speed_Level
;outputs: Enemy_Move_Flag, Ticker
;***********************************************************
CheckTicker PROC

	;retrieve Speed_Level
	mov al, Speed_Level
	
	;see if it's on the first gear
	cmp al, 1d
	je FirstGearSpeed
	
	;see if it's on the second gear
	cmp al, 2d
	je SecondGearSpeed
	
	;see if it's on the third gear
	cmp al, 3d
	je ThirdGearSpeed
	
	;see if it's on the fourth gear
	cmp al, 4d
	je FourthGearSpeed
	
	;see if it's on the fifth gear
	cmp al, 5d
	je FifthGearSpeed
	
	;depending on Speed_Level enemy moves at different rates
	FirstGearSpeed:
		mov ax, Ticker
		cmp ax, 5d
		jge TimesUpToMove
		jmp NoTicker
	
	SecondGearSpeed:
		mov ax, Ticker
		cmp ax, 4d
		jge TimesUpToMove
		jmp NoTicker
	
	ThirdGearSpeed:
		mov ax, Ticker
		cmp ax, 3d
		jge TimesUpToMove
		jmp NoTicker
	
	FourthGearSpeed:
		mov ax, Ticker
		cmp ax, 2d
		jge TimesUpToMove
		jmp NoTicker
	
	FifthGearSpeed:
		mov ax, Ticker
		cmp ax, 1d
		jge TimesUpToMove
		jmp NoTicker
	
	TimesUpToMove:
		;if relevant time passed then raise Enemy_Move_Flag
		mov al, 1d
		mov Enemy_Move_Flag, al
	
	;reset the timer
	mov ax, 0d
	mov Ticker, ax
	
	;finish function
	NoTicker:
		ret
	
CheckTicker ENDP


;Player Movement Functions

;***********************************************************
;							MovePlayerCar
;job: moves player according to the Player_Direction
;	  also updates Color_Offset
;inputs: Player_Direction, Player_Position
;outputs: Player_Direction, Player_Position, Color_Offset
;***********************************************************
MovePlayerCar PROC

	;retrieve Player_Direction
	mov al, Player_Direction
	
	;if it's equal to 0 we don't want to move
	cmp al, 0d
	je FinishMoveCar
	
	;if it's equal to 1 we want to move right
	cmp al, 1d
	je MoveCarRight
	
	;if it's equal to 2 we want to move left
	cmp al, 2d
	je MoveCarLeft
	
	
	;move player to the right
	MoveCarRight:
	
		;update Player_Position to the right
		mov bx, Player_Position
		add bx, 2h
		mov Player_Position, bx
		call UpdatePlayerPositions
		
		;draw the new car
		call DrawTrack
		CarToDraw 0d
		call DrawCar
		CarToDraw 1d
		call DrawCar
		
		;update directions to go back to 0
		mov al, 0d
		mov Player_Direction, al
		
		;increment Color_Offset after each player movement
		;this adds variation to the Randomizer calculation
		mov ax, Color_Offset
		add ax, 1d
		mov Color_Offset, ax
		
		;finish function
		jmp FinishMoveCar
	
	
	;move player to the left
	MoveCarLeft:
	
		;update Player_Position to the left
		mov bx, Player_Position
		sub bx, 2h
		mov Player_Position, bx
		call UpdatePlayerPositions
		
		;draw the new car
		call DrawTrack
		CarToDraw 0d
		call DrawCar
		CarToDraw 1d
		call DrawCar
		
		;reset Player_Direction to 0
		mov al, 0d
		mov Player_Direction, al
		
		;each player movement changes Color_Offset
		;this will be used for making the Randomizer
		;function more random
		mov ax, Color_Offset
		add ax, 1d
		mov Color_Offset, ax
		
	;finish function
	FinishMoveCar:
		ret
MovePlayerCar ENDP


;***********************************************************
;							UpdatePlayerPositions
;job: updates player positions used for collision detection
;	  from the Player_Position
;inputs: Player_Position
;outputs: Player_Position2, Player_Position4, Player_Position6
;		  Player_Position8, Player_Position9, 
;		  Player_Position13
;***********************************************************	
UpdatePlayerPositions PROC

	;retrieving the player position
	mov bx, Player_Position
	
	;calculate collision positions relative to Player_Position
	add bx, 9Eh
	mov Player_Position2, bx
	
	add bx, 4h
	mov Player_Position4, bx
	
	add bx, 13Ch
	mov Player_Position6, bx
	
	add bx, 4h
	mov Player_Position8, bx
	
	add bx, 9Ah
	mov Player_Position9, bx
	
	add bx, 8h
	mov Player_Position13, bx
	

	ret
UpdatePlayerPositions ENDP


;Enemy Movement/Generation Functions

;***********************************************************
;							MoveEnemyCar
;job: move enemy car down when Enemy_Move_Flag is raised
;inputs: Enemy_Move_Flag, Enemy_Position
;outputs: Enemy_Move_Flag, Enemy_Position
;***********************************************************	
MoveEnemyCar PROC

	;if Enemy_Move_Flag is set move the enemy car down
	mov al, Enemy_Move_Flag
	cmp al, 1d
	jne FinishMoveEnemyCar
	
	;update the new position and then redraw the car
	TimeToMoveEnemy:
	
		;erase cells from the old enemy position before moving
		call EraseOverlapEnemyCells
	
		;update the enemy position to be one row down
		mov bx, Enemy_Position
		add bx, 0A0h
		mov Enemy_Position, bx
		call UpdateEnemyPositions
		
		;draw enemy car
		CarToDraw 1d
		call DrawCar
		
		;reset Enemy_Move_Flag
		mov al, 0d
		mov Enemy_Move_Flag, al
		
	;finish function	
	FinishMoveEnemyCar:
		ret
MoveEnemyCar ENDP


;***********************************************************
;							UpdateEnemyPositions
;job: updates enemy positions used for collision detection
;	  from the Enemy_Position
;inputs: Enemy_Position
;outputs: Enemy_Position6, Enemy_Position8, Enemy_Position9
;		  Enemy_Position10, Enemy_Position11, 
;		  Enemy_Position12, Enemy_Position13
;***********************************************************
UpdateEnemyPositions PROC

	;retrieving the enemy position
	mov bx, Enemy_Position
	
	;calculate collision positions relative to Enemy_Position
	add bx, 1DEh
	mov Enemy_Position6, bx
	
	add bx, 4h
	mov Enemy_Position8, bx
	
	add bx, 9Ah
	mov Enemy_Position9, bx
	
	add bx, 2h
	mov Enemy_Position10, bx
	
	add bx, 2h
	mov Enemy_Position11, bx
	
	add bx, 2h
	mov Enemy_Position12, bx
	
	add bx, 2h
	mov Enemy_Position13, bx
	
	
	ret
UpdateEnemyPositions ENDP


;***********************************************************
;							Randomizer
;job: chooses new enemy lane and color using the RTC seconds
;	  and Color_Offset
;inputs: RTC seconds, Color_Offset
;outputs: Seconds, Enemy_Position, Enemy_Color
;***********************************************************	
Randomizer PROC

	;read the current seconds from RTC register 00h
	;the RTC returns the value in BCD format
	mov al, 00h
	out 70h, al
	in al, 71h
	
	;convert the BCD seconds into a decimal value
	mov ah, 0
	mov dl, 10h
	div dl
	mov bl, ah
	mov ah, 0
	
	;multiply the tens digit by 10 and add the ones digit
	mov dl, 10d
	mul dl
	;add the ones to ax to get the seconds in decimal
	add al, bl
	;clear ah so ax contains the converted seconds value
	mov ah, 0d
	
	;we will save the value of ax which is the seconds in decimal to variable
	mov Seconds, ax
	mov dx, Color_Offset
	add ax, dx


	;choose the lane according to Seconds+Color_Offset MOD 3
	mov bl, 3d
	div bl
	
	;ah contains the remainder: 0, 1 or 2
	;remainder 0 selects the left lane
	cmp ah, 0d
	je NewEnemyLeftLane
	
	;remainder 1 makes the middle lane
	cmp ah, 1d
	je NewEnemyMiddleLane
	
	;remainder 2 selects the right lane
	cmp ah, 2d
	je NewEnemyRightLane
	
	;updates the enemy positions to be according to selected new lane
	NewEnemyLeftLane:
		mov bx, Left_Lane_Position
		mov Enemy_Position, bx
		call UpdateEnemyPositions
		jmp ColorChooser
	
	NewEnemyMiddleLane:
		mov bx, Middle_Lane_Position
		mov Enemy_Position, bx
		call UpdateEnemyPositions
		jmp ColorChooser
	
	NewEnemyRightLane:
		mov bx, Right_Lane_Position
		mov Enemy_Position, bx
		call UpdateEnemyPositions
		
		
	ColorChooser:
		;use a similar calculation to choose color of new enemy car
		;this time we use MOD 5 and not MOD 3
		mov ax, Seconds
		mov dx, Color_Offset
		add ax, dx
		mov bl, 5d
		div bl
		
		
		;ah contains the remainder: 0, 1, 2, 3, or 4
		;convert the remainder to a word offset for the color array
		mov al, ah
		mov ah, 0h
		shl ax, 1
		mov bx, ax
		
		;use bx as the offset into the color array
		mov ax, Enemy_Color_Selection[bx]
		mov Enemy_Color, ax
		jmp FinishRandomizer
		
	;finish function
	FinishRandomizer:

	ret
Randomizer ENDP


;***********************************************************
;							EndOfTrack
;job: checks if enemy has reached the end of the track
;inputs: Enemy_Position11, Score, Speed_Level
;outputs: Score, Enemy_Position, Enemy_Color
;***********************************************************
EndOfTrack PROC
	
	;see if the enemy has reached the last row of any lane
	mov bx, Enemy_Position11
	cmp bx, 0E92h
	je RespawnNewEnemy
	
	cmp bx, 0EAEh
	je RespawnNewEnemy
	
	cmp bx, 0ECAh
	je RespawnNewEnemy
	
	;if not then end the function
	jmp FinishEndOfTrack
	
	
	RespawnNewEnemy:
		;redraws the track and player
		call DrawTrack
		CarToDraw 0d
		call DrawCar
		;respawns a new enemy in a randomly selected lane
		call Randomizer
		CarToDraw 1d
		call DrawCar
		
	
	AddPoints:
	;updates points 
		call UpdateScoreAdder
		mov ax, Score
		mov dx, Score_Adder
		add ax, dx
		mov Score, ax

	;finish function
	FinishEndOfTrack:

	ret
EndOfTrack ENDP


;Collision Functions

;***********************************************************
;							CheckCollision
;job: check if the player collided with the enemy or wall
;inputs: Player_Position, Player_Position2, Player_Position4
;		 Player_Position6, Player_Position8, 
;		 Player_Position9, Player_Position13
;		 Enemy_Position, Enemy_Position6, Enemy_Position8, 
;        Enemy_Position9, Enemy_Position10, Enemy_Position11 
;		 Enemy_Position12, Enemy_Position13
;		 Left_Wall, Right_Wall
;outputs: Is_Collision
;***********************************************************
CheckCollision PROC

	;wall collisions
	CollisionWith Left_Wall, Player_Position9
	CollisionWith Right_Wall, Player_Position13
	
	;car collisions
	CollisionWith Player_Position, Enemy_Position9
	CollisionWith Player_Position, Enemy_Position10
	CollisionWith Player_Position, Enemy_Position11
	CollisionWith Player_Position, Enemy_Position12
	CollisionWith Player_Position, Enemy_Position13
	
	CollisionWith Player_Position2, Enemy_Position8
	CollisionWith Player_Position2, Enemy_Position13
	
	CollisionWith Player_Position4, Enemy_Position6
	CollisionWith Player_Position4, Enemy_Position9
	
	CollisionWith Player_Position6, Enemy_Position13
	
	CollisionWith Player_Position8, Enemy_Position9
	
	CollisionWith Player_Position9, Enemy_Position13
	
	CollisionWith Player_Position13, Enemy_Position9
	
	;if nothing collided then finish the function
	jmp FinishCheckCollision
	
	;raise Is_Collision flag if there was a collision
	CheckCollisionRaiseFlag:
		mov al, 1d
		mov Is_Collision, al
		
	
	;finish function
	FinishCheckCollision:
	ret
	
CheckCollision ENDP


;Drawing Functions

;***********************************************************
;							DrawTrack
;job: draw the race track, grass, side walls and lane markings
;inputs: Cheats_Correct, Desert_Color
;outputs: beautifully designed 80x25 textmode racing track
;***********************************************************	
DrawTrack PROC

;draw the left side grass using a nested loop for rows and columns
	mov cx, 19h
	mov bx, 0h
	
	GrassRows:
		push cx
		mov cx, 12h
		
			GrassColumns:
				
				;print different colors if cheats are activated
				mov al, Cheats_Correct
				cmp al, 1d
				je GrassCheatColor
				
				jmp GrassNormalColor
				
				GrassCheatColor:
					mov ax, Desert_Color
					jmp DrawGrass
			
				GrassNormalColor:
					mov ax, Green_Color
					
				;write the selected color and character to video memory
				DrawGrass:
				mov es:[bx], ax
				add bx, 2h
			
			Loop GrassColumns
			
		pop cx
		add bx, 7Ch

	Loop GrassRows


;draw the left red and white walls using a loop
	mov cx, 5h
	mov bx, 24h
	
	RedWhiteLines:
		mov ax, Red_Color
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
		
		mov ax, White_Color
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
	
	Loop RedWhiteLines
	


;draw the grey road using a nested loop
	mov cx, 19h
	mov bx, 26h
	
	GreyRows:
		push cx
		mov cx, 29h
		
			GreyColumns:
				mov ax, Grey_Color
				mov es:[bx], ax
				add bx, 2h
			
			Loop GreyColumns
			
		pop cx
		add bx, 4Eh

	Loop GreyRows



;draw the right side red and white lines using a loop
	mov cx, 5h
	mov bx, 78h
	
	RedWhiteLines2:
	
		mov ax, Red_Color
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
		
		
		mov ax, White_Color
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
		mov es:[bx], ax
		add bx, 0A0h
	
	Loop RedWhiteLines2




;draw the right side grass using a nested loop for rows and columns
;this loop will have one more column because the screen is even (80 characters)
;but the track is odd because the player is an odd amount of spaces
;this means one side will be one space longer than the other side

		mov cx, 19h
		mov bx, 7Ah
		Grass2Rows:
		
			push cx
			mov cx, 13h
			
				Grass2Columns:
				
					;print different colors if cheats are activated
					mov al, Cheats_Correct
					cmp al, 1d
					je Grass2CheatColor
					
					jmp Grass2NormalColor
					
					Grass2CheatColor:
						mov ax, Desert_Color
						jmp DrawGrass2
				
					Grass2NormalColor:
						mov ax, Green_Color
					
					;write the selected color and character to video memory
					DrawGrass2:
					mov es:[bx], ax
					add bx, 2h
			
			
				Loop Grass2Columns
				
			pop cx
			add bx, 7Ah

		Loop Grass2Rows



;draw the yellow lanes using loops
	
		mov cx, 5h
		mov bx, 0E0h
		
		YellowLanes1:
			
			mov ax, Yellow_Lane_Color
			mov es:[bx], ax
			add bx, 0A0h
			mov es:[bx], ax
			add bx, 0A0h
			mov es:[bx], ax
			add bx, 1E0h
		
		Loop YellowLanes1
		
		mov cx, 5h
		mov bx, 0FCh
		
		YellowLanes2:
			
			mov ax, Yellow_Lane_Color
			mov es:[bx], ax
			add bx, 0A0h
			mov es:[bx], ax
			add bx, 0A0h
			mov es:[bx], ax
			add bx, 1E0h
		
		Loop YellowLanes2
		
	ret
	
DrawTrack ENDP


;***********************************************************
;							DrawCar
;job: draw either the player or enemy car
;inputs: DrawCar_Car_Choice, Player_Position, Enemy_Position
;		 Player_Color, Enemy_Color
;outputs: DrawCar_Car_Color
;***********************************************************
DrawCar PROC
	
	;retrieve DrawCar_Car_Choice to know which car to draw now
	mov al, DrawCar_Car_Choice
	cmp al, 0d
	je DrawPlayerCar
	jmp DrawEnemyCar
	
	;set up the player car position and color
	DrawPlayerCar:
		;load Player_Position as starting bx
		mov bx, Player_Position
		
		;if there is a cheat code then change the car color
		mov al, Cheats_Correct
		cmp al, 1d
		je CarCheatColor
		;otherwise use normal car color
		jmp CarNormalColor

		;if the cheat codes activated change color of car
		CarCheatColor:
			mov ax, Brown_Color
			mov DrawCar_Car_Color, ax
		
		jmp DrawTheCar
			
			
		;if there are no cheat codes
		CarNormalColor:
			mov ax, Player_Color
			mov DrawCar_Car_Color, ax
		
		jmp DrawTheCar
	
	
	;enter information for drawing enemy car
	DrawEnemyCar:
		;load Enemy_Position as starting bx
		mov bx, Enemy_Position
		
		;enter enemy color
		mov ax, Enemy_Color
		mov DrawCar_Car_Color, ax
		
		jmp DrawTheCar
	
	
	
	DrawTheCar:
	;Top row
	mov ax, DrawCar_Car_Color
	mov es:[bx], ax 
	
	;Second row
	;Middle 
	add bx, 0A0h
	mov ax, DrawCar_Car_Color
	mov es:[bx], ax
	;Front left wheel
	sub bx, 2h
	mov ax, Black_Color
	mov es:[bx], ax
	;Front Right wheel
	add bx, 4h
	mov ax, Black_Color
	mov es:[bx], ax
	
	;Third row
	add bx, 9Eh
	mov ax, Cyan_Color
	mov es:[bx], ax
	
	;Fourth row
	;Middle
	add bx, 0A0h
	mov ax, DrawCar_Car_Color
	mov es:[bx], ax
	;Back left wheel
	sub bx, 2h
	mov ax, Black_Color
	mov es:[bx], ax
	;Back right wheel
	add bx, 4h
	mov ax, Black_Color
	mov es:[bx], ax
	
	;Fifth row
	mov cx, 5h
	add bx, 9Ah
	CarBack:
		mov ax, Black_Color
		mov es:[bx], ax
		add bx, 2h
	Loop CarBack

	ret
DrawCar ENDP


;***********************************************************
;							EraseOverlapEnemyCells
;job: "erase" old enemy cells that are not covered after the movement
;inputs: Enemy_Position
;outputs: clean enemy movement
;***********************************************************
EraseOverlapEnemyCells PROC

	;load Enemy_Position into bx
	mov bx, Enemy_Position
	
	;calculate and erase the required cells relative to Enemy_Position
	mov ax, 7020h
	mov es:[bx], ax
	
	add bx, 9Eh
	mov es:[bx], ax
	add bx, 4h
	mov es:[bx], ax
	
	add bx, 140h
	mov es:[bx], ax
	sub bx, 4h
	mov es:[bx], ax
	
	add bx, 9Eh
	mov es:[bx], ax
	add bx, 8h
	mov es:[bx], ax
	
	ret
EraseOverlapEnemyCells ENDP


;***********************************************************
;							ClearScreen
;job: clean the entire 80x25 screen by writing black spaces
;to video memory
;inputs: Black_Color
;outputs: the screen becomes entirely black
;***********************************************************
ClearScreen PROC

	mov cx, 2000d
	mov ax, Black_Color
	mov bx, 0h
	
	EraseScreen:
		mov es:[bx], ax
		add bx, 2h
		
	dec cx
	jnz EraseScreen


	ret
ClearScreen ENDP


;===========================================================
;							Main Game Program
;===========================================================

START:

	.startup
	
		
	;set ES to segment 0000h where the IVT is located
	mov ax, 0h
	mov es, ax
	
	;disable hardware interrupts while modifying the IVT
	cli
	
	;copy the original int 9 to new free address 80h
	mov ax, es:[9h*4]
	mov es:[80h*4], ax
	mov ax, es:[9h*4+2]
	mov es:[80h*4+2], ax
	
	;replace the int 9 with the address of ISR_New_int9
	mov ax, offset ISR_New_int9
	mov es:[9h*4], ax
	mov ax, cs
	mov es:[9h*4+2], ax
	
	;copy the original int 8 to new free address 84h
	mov ax, es:[8h*4]
	mov es:[84h*4], ax
	mov ax, es:[8h*4+2]
	mov es:[84h*4+2], ax
	
	;replace the int 8 with the address of ISR_New_int8
	mov ax, offset ISR_New_int8
	mov es:[8h*4], ax
	mov ax, cs
	mov es:[8h*4+2], ax
	
	;reenable hardware interrupts
	sti

	;set ES to screen memory
	mov ax, 0b800h
	mov es, ax

	;set up and show the mouse
	mov ax, 00h
	int 33h
	mov ax, 01h
	int 33h
	
	
	StartScreen:
		
		;prints the background and the initial welcome messages
		call DrawTrack
		call PrintWelcomeScreen
		
		PressStart:
		
			;checks if the Press Start button was clicked
			call CheckForStartClick
			
			;waits until the press start button is clicked
			;if clicked move onto asking about cheat codes
			mov al, Start_Click
			cmp al, 1d
			je CheatCodes
			jmp PressStart
			
		
		CheatCodes:
			
			;checks if user claims to have cheat code
			call CheckCheats
			
			;if user doesn't have cheat code then continue to the game
			mov al, Cheats_Availability
			cmp al, 0d
			je PreGameLoop
			
			;if user has cheat code then ask for the cheat code
			cmp	al, 1d
			je EnterCheats
			
			;if a character that isn't n or y is entered
			;continue asking to put in letter
			jmp StartScreen
			
			
		EnterCheats:
		
			;checks entered cheat code with expected cheat code 
			call VerifyCheatCode
			jmp CheatStartScreen
			
			
	CheatStartScreen:
		
		;if the cheat was correct then the screen will be different
		;if the cheat was incorrect nothing would have changed
		call DrawTrack
		call PrintWelcomeScreen
		
		;reset the Press Start flag 
		mov al, 0d
		mov Start_Click, al
		
		;show the mouse
		mov ax, 01h
		int 33h
		
		
		CheatsPressStart:
		
			;checks if the Press Start button was clicked
			call CheckForStartClick
			
			;waits until the press start button is clicked
			;if clicked move onto setting up the game screen
			mov al, Start_Click
			cmp al, 1d
			je PreGameLoop
			jmp CheatsPressStart
			
		
	PreGameLoop:
	
		;hides the mouse
		mov ax, 02h
		int 33h
	
		;draw the initial game state of background, player, and enemy
		call DrawTrack
		CarToDraw 0d
		call DrawCar
		call Randomizer
		CarToDraw 1d
		call DrawCar
		
		;reset Ticker before entering the game loop
		mov ax, 0d
		mov Ticker, ax
	
	
	GameLoop:
	
		;general game loop of moving the player if requested
		call MovePlayerCar
		
		;check the timer and move the enemy when required
		call CheckTicker
		call MoveEnemyCar
		
		;check for collision
		call CheckCollision
		mov al, Is_Collision
		cmp al, 1d
		je GameOverScreen
		
		;if no collision check if enemy reached end of track
		call EndOfTrack
		
		;update the score and speed 
		call UpdateScore
		call UpdateSpeed
		
		;check for score overflow
		;automatically end game if overflow occurs
		call CheckScoreOverflow
		mov al, Is_Score_Overflow
		cmp al, 1d
		je GameOverScreen
		
	jmp GameLoop

	
	GameOverScreen:
		
		;prints the gameover message
		call PrintGameOverScreen
		
		;checks if the game ended because of score overflow
		mov al, Is_Score_Overflow
		cmp al, 1d
		je GameOverFlow
		jmp NoGameOverFlow
		
			GameOverFlow:
				;if there is a overflow then print special overflow messages
				call ScoreOverflow
				jmp ContinueGameOverScreen
		
			NoGameOverFlow:
				;if there is no overflow just display the final score and speed
				call UpdateScore
				call UpdateSpeed
		
	ContinueGameOverScreen:
		;show the mouse cursor again
		mov ax, 01h
		int 33h

		CheckForPlayAgainAnswer:
		
			;checks if player wants to play again
			call CheckForPlayAgain
			mov al, Play_Again_Click
			cmp al, 1d
			je PlayAgain
			
			cmp al, 0d
			je EndGame
			
			;if nothing was clicked wait for click
			cmp al, 2d
			je CheckForPlayAgainAnswer
		
		
		PlayAgain:
			
			;if playing again reset all relevant flags
			call ResetGame
			
			;jump back to setting up the game
			jmp PreGameLoop
				

		EndGame:
		
			;hides the mouse
			mov ax, 02h
			int 33h
			
			;clear the screen before exiting
			call ClearScreen
			
			;moves cursor to top of screen for continued instructions
			MoveCursor 0h, 0h	
			.exit
			
END START