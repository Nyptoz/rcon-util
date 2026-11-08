import winim/com
import std/json, std/terminal, std/strutils, std/os, std/osproc

# Print the version of the RCON client
const VERSION = "1.0.1"
echo "Nyptoz Windows RCON Client " & VERSION & "\n"

# Fetch config.json file from the current directory
const configFile = "config.json"
try:
  if not fileExists(configFile):
    echo "Creating config.json..."
    let defaultConfig = %* {
      "rcon_path": "<your_rcon_client_path>",
      "servers": []
    }
    writeFile(configFile, $defaultConfig)
    echo "config.json created. Please edit it to add your RCON server information."
    quit(1)
except OSError as e:
  echo "Error: Unable to access config.json - ", e.msg
  quit(1)

let config = parseFile(configFile)
let rcon_path = config["rcon_path"].getStr()

# Check if rcon_path is set in config.json
if rcon_path == "":
  echo "Error: rcon_path is not set in config.json"
  quit(1)

# Read options from config.json and display them as options
let servers = config["servers"].getElems()
var configIndex: int

# No servers
if servers.len == 0:
    echo "No servers found in config.json"
    quit(1)
# Several servers > let user choose one
elif servers.len > 1:
    echo "Please select a rcon server using the number:"

    for i, server in config["servers"].getElems():
        echo $(i + 1) & " " & server["name"].getStr()

    # Read user input for server selection over and over until a valid selection is made
    while true:
        write(stdout, "> ")
        configIndex = readLine(stdin).parseInt() - 1
        if configIndex >= 0 and configIndex < servers.len:
            break
        else:
            echo "Invalid selection. Please try again."
# Only one server > select it automatically
elif servers.len == 1:
    echo "Only one server found in config.json. Selecting it automatically."
    configIndex = 0

# Select the server based on the user's choice
let server = servers[configIndex]
let serverName = server["name"].getStr()

echo "Selected server: " & serverName

# Fetch saved passwords from passwords.json file
const passwordsFile = "passwords.json"

# Check if passwords.json exists, if not create it with an empty saved_passwords array
if not fileExists(passwordsFile):
    echo "Creating passwords.json..."
    let defaultPasswords = %* {
      "saved_passwords": []
    }
    writeFile(passwordsFile, $defaultPasswords)
    echo "passwords.json created."

var passwordSaved = false

let savedPasswords = parseFile(passwordsFile)["saved_passwords"].getElems()
if savedPasswords.len > 0:
    for savedPassword in savedPasswords:
        if savedPassword["server_name"].getStr() == serverName:
            echo "Found saved password for this server."
            let password = savedPassword["rcon_password"].getStr()
            echo "Using saved password."
            passwordSaved = true
            break

# Read the password from stdin without echoing it to the console
let password = readPasswordFromStdin("Please enter the rcon password for " & serverName & ": ")

# Build the arguments for the rcon client based on the selected server and the provided password
let args = [
  "-H", server["ip"].getStr(),
  "-P", $server["port"].getInt(),
  "-p", password,
  "-i"
]

echo "Attempting to connect to server..."

# Connect user to the RCON server using the rcon client and the provided arguments
let p = startProcess(
  rcon_path,
  args = args,
  options = {poParentStreams}
)
let exitCode = p.waitForExit()
p.close()

# Check the exit code of the RCON client and display an error message if it is not 0
if exitCode != 0:
  echo "RCON client exited with code ", exitCode
else:
  # If the password was not already saved, don't ask the user to save it again
  if passwordSaved: quit(0)

  write(stdout, "Do you want to save the password for future use? (y/n): ")

  # Read user input for saving the password
  let savePasswordAnswer = readLine(stdin).strip().toLowerAscii()
  if savePasswordAnswer in ["y", "yes"]:
    let newSavedPasswordEntry = %* {
      "server_name": serverName,
      "rcon_password": password
    }

    # Create a new array with the existing saved passwords and the new password entry
    var updatedPasswords = savedPasswords
    updatedPasswords.add(newSavedPasswordEntry)

    # Create a new JSON object with the updated saved passwords
    let updatedPasswordsJson = %* {
      "saved_passwords": updatedPasswords
    }
    # Save the updated passwords to passwords.json
    writeFile(passwordsFile, $updatedPasswordsJson)
    echo "Password saved successfully."
  else:
    echo "Password not saved."