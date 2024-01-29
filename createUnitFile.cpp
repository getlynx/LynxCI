#include <iostream>
#include <string>
#include <fstream>
#include <openssl/evp.h>
#include <iomanip>
#include <sstream>
#include <chrono>

using namespace std;
using namespace chrono;

// To compile and execute this program, run the following CLI command.
// g++ createUnitFile.cpp  -o createUnitFile -I/opt/homebrew/Cellar/openssl@3/3.2.0_1/include -L/opt/homebrew/Cellar/openssl@3/3.2.0_1/lib -lssl -lcrypto && ./createUnitFile

// The path to the systemd unit file.
const string unitFile = "lynx.service"; // /etc/systemd/system/lynx.service
// The expected hash for the above file.
const string knownHash = "6a2808a4183f3f569b4e5151f59c09b9359eab7b881ec40244c429d284589160";
// Debug output
const bool debug = 0;

void setUnitFilePermissions(const string& unitFile) {
    string unitFileFinal = "chmod +x \"" + unitFile + "\"";
    int result = system(unitFileFinal.c_str());

    if (result == 0) {
        if (debug == 1) std::cout << "File permissions reset." << std::endl;
    } else {
        if (debug == 1) std::cout << "File permissions not reset. Error with bash command." << std::endl;
    }
}

bool fileExists(const string& filePath) {
    ifstream file(filePath.c_str());
    return file.good();
}

// Function to calculate the SHA-256 hash of a file
string calculateSHA256(const string& filePath) {
    ifstream file(filePath, ios::binary);

    if (!file.is_open()) {
        cerr << "Error: Unable to open file." << endl;
        return "";
    }

    EVP_MD_CTX* mdContext = EVP_MD_CTX_new();
    EVP_MD_CTX_init(mdContext);
    EVP_DigestInit_ex(mdContext, EVP_sha256(), nullptr);

    const int bufferSize = 4096;
    char buffer[bufferSize];

    while (!file.eof()) {
        file.read(buffer, bufferSize);
        EVP_DigestUpdate(mdContext, buffer, file.gcount());
    }

    file.close();

    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int hashLength;

    EVP_DigestFinal_ex(mdContext, hash, &hashLength);
    EVP_MD_CTX_free(mdContext);

    stringstream ss;
    for (unsigned int i = 0; i < hashLength; ++i) {
        ss << hex << setw(2) << setfill('0') << static_cast<int>(hash[i]);
    }

    return ss.str();
}

void createUnitFile(const string& unitFile) {

    // Create an ofstream object and open a file
    ofstream outputFile(unitFile);

    // Check if the file is opened successfully
    if (outputFile.is_open()) {
        // Write data to the file

        outputFile << "[Unit]" << endl;
        outputFile << "Description=Lynx Core" << endl;
        outputFile << "After=network.target" << endl;
        outputFile << "" << endl;
        outputFile << "[Service]" << endl;
        outputFile << "Type=forking" << endl;
        outputFile << "User=root" << endl;
        outputFile << "Group=root" << endl;
        outputFile << "Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" << endl;
        outputFile << "ExecStart=/usr/local/bin/lynxd" << endl;
        outputFile << "ExecStop=/usr/local/bin/lynx-cli stop" << endl;
        outputFile << "Restart=always" << endl;
        outputFile << "RestartSec=30" << endl;
        outputFile << "" << endl;
        outputFile << "[Install]" << endl;
        outputFile << "WantedBy=multi-user.target" << endl;

        // Close the file
        outputFile.close();

        if (debug == 1) std::cout << "File written successfully." << endl;
    } else {
        if (debug == 1) std::cout << "Unable to open the file." << endl;
    }

}

int main() {

    // Record the start time of this program
    high_resolution_clock::time_point startTime = high_resolution_clock::now();

    // Only execute this script if it matches the intended target OS

    // Only execute this script if it's running as the root user

    // Iterate through the loop 5 times
    for (int i = 0; i < 3; ++i) {

        // Check if the file exists in the target directory?
        if (fileExists(unitFile)) {

            if (debug == 1) std::cout << "System Unit File found. Checking for a hash match..." << endl;

            // Calculate the SHA-256 hash of the file
            string calculatedHash = calculateSHA256(unitFile);
            if (debug == 1) std::cout << "Existing file hash: " + calculatedHash << endl;
            if (debug == 1) std::cout << "Expected file hash: " + knownHash << endl;

            // Compare the calculated hash with the known hash
            if (calculatedHash == knownHash) {
                if (debug == 1) std::cout << "Hashes match. File is valid." << endl;
            } else {
                if (debug == 1) std::cout << "Hashes do not match. File may be corrupted or tampered with." << endl;

                // Get the current time point with high resolution
                std::chrono::system_clock::time_point currentTimePoint = std::chrono::system_clock::now();
                std::time_t currentTime = std::chrono::system_clock::to_time_t(currentTimePoint);

                // Convert the timestamp to a string
                std::ostringstream oss;
                oss << std::put_time(std::localtime(&currentTime), "%Y-%m-%d-%H-%M-%S");
                std::string formattedTime = oss.str();
                string fullFormattedTime = unitFile + "." + formattedTime;

                // Output the formatted time
                if (debug == 1) std::cout << "Formatted Time: " << formattedTime << std::endl;
                if (debug == 1) std::cout << "Full Formatted Time: " << fullFormattedTime << std::endl;

                // Attempt to rename the file
                if (std::rename(unitFile.c_str(), fullFormattedTime.c_str()) == 0) {
                    if (debug == 1) std::cout << "File renamed successfully." << std::endl;
                } else {
                    if (debug == 1) std::cerr << "Error renaming the file." << std::endl;
                }

            }

        } else {

            if (debug == 1) std::cout << "File does not exist." << std::endl;

            // Create the System unit file.
            createUnitFile(unitFile);

        }

        if (debug == 1) std::cout << "Loop " << i + 1 << std::endl;
    }

    // Set file permissions.
    setUnitFilePermissions(unitFile);

    // Record the end time
    high_resolution_clock::time_point endTime = high_resolution_clock::now();
    // Calculate the duration
    milliseconds duration = duration_cast<milliseconds>(endTime - startTime);
    // Output the duration in milliseconds
    if (debug == 1) std::cout << "Program execution time: " << duration.count() << " milliseconds" << endl;

    return 0;
}
