function Test-TcpPort ($IPs,$TcpPort) {
foreach ($IP in $IPs) {
    try {
        ## Create the TcpClient object and initiate a Connect method
        $socket = new-object Net.Sockets.TcpClient
        $socket.Connect($IP, $TcpPort)
        ## The script will only get here if an error is not thrown by the above method
        $status = "Open"
        ## Properly close the TCP connection once we're done
        $socket.Close()
        $Hostname = [System.Net.Dns]::GetHostByAddress($IP).HostName
    } catch {
        $status = 'Closed/Filtered'
    } finally {
        $obj = [PSCustomObject]@{
            IP = $IP
            Hostname = $Hostname
            TcpPort = $TcpPort
            Status = $status
        }
        $obj
    }
}
}

## Usage
$IPs = '10.56.59.143','10.84.107.19','10.240.128.188'
$TcpPort = '1433'

Test-TcpPort $IPs $TcpPort

