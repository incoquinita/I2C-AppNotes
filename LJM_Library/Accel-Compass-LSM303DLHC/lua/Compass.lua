--This is an example that uses the LSM303DLHC Accelerometer & Magnetometer on the I2C Bus on EIO4(SCL) and EIO5(SDA)
--outputs data to:
--X mag = 46000
--Y mag = 46002
--Z mag = 46004

I2C_Utils= {}
function I2C_Utils.configure(self, sda, scl, speed, options, slave, debug)--Returns nothing
  self.sda = sda --FIO0:7 = 0:7, EIO0:7 = 8:15, CIO0:7 = 16:23
  self.scl = scl --FIO0:7 = 0:7, EIO0:7 = 8:15, CIO0:7 = 16:23
  self.speed = speed ----0=fastest; 65535=fastest; 65534, 65533, etc. gets slower.
  self.options = options
  self.slave = slave --7-bit slave address
  self.speed = speed
  self.debugEn = debugEn
  MB.W(5100, 0, self.sda)
  MB.W(5101, 0, self.scl)
  MB.W(5102, 0, self.speed)
  MB.W(5103, 0, self.options)
  MB.W(5104, 0, self.slave)
end
function I2C_Utils.data_read(self, numBytesRX)--Returns an array of {numAcks, Array of {bytes returned}}
  local numBytesTX = 0
  MB.W(5108, 0, numBytesTX)
  MB.W(5109, 0, numBytesRX)
  MB.W(5110, 0, 1)
  local dataRX = MB.RA(5160, 99, numBytesRX)
  local numAcks = MB.R(5114, 1)
  return {numAcks, dataRX}
end
function I2C_Utils.data_write(self, dataTX)--Returns an array of {NumAcks, errorVal}
  local numBytesRX = 0
  local numBytesTX = table.getn(dataTX)
  MB.W(5108, 0, numBytesTX)
  MB.W(5109, 0, numBytesRX)
  local errorVal = MB.WA(5120, 99, numBytesTX, dataTX)
  MB.W(5110, 0, 1)
  local numAcks = MB.R(5114, 1)
  return {numAcks, errorVal}
end
function I2C_Utils.data_write_and_read(self, dataTX, numBytesRX)--Returns an array of {numAcks, Array of {bytes returned}, errorVal}
  local numBytesTX = table.getn(dataTX)
  MB.W(5108, 0, numBytesTX)
  MB.W(5109, 0, numBytesRX)
  local errorVal = MB.WA(5120, 99, numBytesTX, dataTX)
  MB.W(5110, 0, 1)
  local numAcks = MB.R(5114, 1)
  local dataRX = MB.RA(5160, 99, numBytesRX)
  return {numAcks, dataRX, errorVal}
end
function I2C_Utils.calc_options(self, resetAtStart, noStopAtStarting, disableStretching)--Returns a number 0-7
  self.resetAtStart = resetAtStart
  self.noStop = noStopAtStarting
  self.disableStre = disableStretching
  local optionsVal = 0
  optionsVal = self.resetAtStart*1+self.noStop*2+self.disableStre*4
  return optionsVal
end
function I2C_Utils.find_all(self, minAddr, maxAddr)--Returns an array of all valid addresses, in number form
  local validAddresses = {}
  for slaveAddr = minAddr, maxAddr do
    MB.W(5104, 0, slaveAddr)
    local numBytesTX = 0
    local numBytesRX = 0
    MB.W(5108, 0, numBytesTX)
    MB.W(5109, 0, numBytesRX)
    MB.W(5110, 0, 1)
    local numAcks = MB.R(5114, 1)
    if numAcks ~= 0 then
      table.insert(validAddresses,slaveAddr)
    end
    for j = 0, 2000 do end
  end
  local addrLen = table.getn(validAddresses)
  if addrLen == 0 then
    print("No valid addresses were found")
  end
  MB.W(5104, 0, self.slave)
  return validAddresses
end
function convert_16_bit(msb, lsb, conv)--Returns a number, adjusted using the conversion factor. Use 1 if not desired  
  res = 0
  if msb >= 128 then
    res = (-0x7FFF+((msb-128)*256+lsb))/conv
  else
    res = (msb*256+lsb)/conv
  end
  return res
end

magI2C = I2C_Utils

magAddr = 0x1E
magI2C.configure(magI2C, 13, 12, 65516, 0, magAddr, 0)--configure the I2C Bus

addrs = magI2C.find_all(magI2C, 0, 127)
addrsLen = table.getn(addrs)
for i=1, addrsLen do--verify that the target device was found     
  if addrs[i] == magAddr then
    print("I2C Magnetometer Slave Detected")
    break
  end
end

--init slave
magI2C.data_write(magI2C, {0x00, 0x14})
magI2C.data_write(magI2C, {0x01, 0x20})
magI2C.data_write(magI2C, {0x02, 0x00})

LJ.IntervalConfig(0, 500)
while true do
  if LJ.CheckInterval(0) then

    dataRaw = {}
    for i=0, 5 do
      magI2C.data_write(magI2C, {0x03+i})
      dataIn = magI2C.data_read(magI2C, 1)[2][1]  
      table.insert(dataRaw, dataIn)
    end
    data = {}
    table.insert(data, convert_16_bit(dataRaw[1], dataRaw[2], 1100))
    table.insert(data, convert_16_bit(dataRaw[3], dataRaw[4], 11000))
    table.insert(data, convert_16_bit(dataRaw[5], dataRaw[6], 980))
    for i=0, 2 do
      MB.W(46000+i*2, 3, data[i+1])
    end
    for i=0, 2 do
      print(data[1+i])
    end
    print("------")
  end
end