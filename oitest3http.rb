###########################################################
# oitest2http.rb         (C) 2014-15 stat-eb
###########################################################
# Simple program to download joystick from server
# and send drive commands to iRobot Create
###########################################################


###########################################################
# Configuration goes here
###########################################################
# the code automatically chooses the correct way to connect
# to the robot based on what you uncomment and configure
# here.

# choose a local serial port
#portname = "COM6"

# connect using TCP/IP
hostname = '10.50.1.50'
portnumber = 2364

# dump all writes to a file (if no robot attached)
#filename = "f:/oitest.txt"


###########################################################
# Start of Code
###########################################################

require "serialport" # for direct serial port
require "socket" # for TCP/IP connection

require "bindata" # for roomba protocol
require "net/http" # to fetch joystick from server

###########################################################
# All our functions are defined here
###########################################################

# Retrieve the joystick status page specified,
# Returns [x, y]
def TestHttpJoystick(url)
	
	# load the page with joystick status
	html = Net::HTTP.get(URI(url))
	# find the special machine tag we put in
	machinetag = html[/<!-- Machine.*-->/]

	# for debugging purposes, make sure we read the machine tag properly
	#print machinetag

	# Scan for the actual numbers (This regexp works fine)
	numberstrings = machinetag.scan(/ [-.[:digit:]]+/)[0..1]

	# convert x and y to floats, and return as an array
	return [numberstrings[0].to_f, numberstrings[1].to_f]
end

# Subtract d distance from (x, y)
# returns [x, y]
def ReduceDistance(x, y, d)
	# Pythagorean theorm to find old distance
	old_distance = (((x ** 2) + (y ** 2)) ** 0.5)
	
	# Find new distance
	new_distance = old_distance - d
	new_distance = 0 if old_distance < d
	
	# Find scale factor
	# Be careful not to divide by zero
	if old_distance == 0
		scale_factor = 0
	else
		scale_factor = new_distance / old_distance
	end
	
	# Apply scale factor
	x = x * scale_factor
	y = y * scale_factor
	
	# Return coordinates as an array
	return x, y
end


# Takes in floating point joystick parameters
# Outputs [left, right] array to drive Create
def JoystickToRoomba(x, y)
	# Reduce strat motion from poorly centered controls
	x, y = ReduceDistance(x, y, 0.1)
	
	# Reduce x, to make controls nicer
	x = x * 0.5
	
	# Implement a simple differential drive
	left  = -y + x
	right = -y - x
	
	# Apply scale factor
	left  = left  * 500
	right = right * 500
	
	# Turn into integers
	left  = left.truncate
	right = right.truncate
	
	# Clamp to +-500 drive
	left  = [left,  -500, 500].sort[1]
	right = [right, -500, 500].sort[1]
	
	# return our calculated values
	return [left, right]
end

# Retrieve joystick status, process, and send it to Create
def AutoJoystickOnce(serial)
	# Get joystick
	x, y = TestHttpJoystick('http://127.0.0.1:3000/joysticks/1')
	
	# Turn to left, right
	left, right = JoystickToRoomba(x, y)
	
	# Diagnostics message
	printf("L:%4d R: %4d\n", left, right)
	
	# Send to roomba
	DriveDirect(serial, left, right)
end

# https://github.com/dmendel/bindata/wiki/Records

class CreateOI
	class CreateDriveCommand < BinData::Record
		uint8	:command, :value => 145
		int16be	:right
		int16be	:left
	end
end

def DriveDirect(serial, left, right)
	command = CreateOI::CreateDriveCommand.new
	command.left  = left
	command.right = right
	command.write(serial)
end


###########################################################
# initialize all our ports, etc
###########################################################

# open serial
if defined? portname
	serial = SerialPort.new( portname )
	serial.set_modem_params(57600, 8, 1, SerialPort::NONE)
	serial.binmode
end

# open network
if defined? hostname
	serial = Socket.new( Socket::AF_INET, Socket::SOCK_STREAM )
	#serial.connect( Socket.pack_sockaddr_in( 2364, 'ahs-mini-01' ) )
	serial.connect( Socket.pack_sockaddr_in( portnumber, hostname ) )
end

# dump to file for now
if defined? filename
	serial = File.new( filename, "w" )
end


###########################################################
# This is our main code
###########################################################

# Track the joystick
AutoJoystickOnce(serial) while true

# Stop
DriveDirect(serial, 0, 0)
