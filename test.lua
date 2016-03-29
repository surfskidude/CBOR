-- ***************************************************************
--
-- Copyright 2016 by Sean Conner.  All Rights Reserved.
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or (at your
-- option) any later version.
-- 
-- This library is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
-- License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public License
-- along with this library; if not, see <http://www.gnu.org/licenses/>.
--
-- Comments, questions and criticisms can be sent to: sean@conman.org
--
-- luacheck: globals ddt lpeg dump safestring cbor DISP compare roundtrip
-- ***************************************************************

ddt        = require "org.conman.debug"
lpeg       = require "lpeg"
dump       = require "org.conman.table".dump
safestring = require "org.conman.table".safestring
cbor       = require "cbor"

-- ***********************************************************************

local function assertf(cond,...)
  local msg = string.format(...)
  assert(cond,msg)
end

-- ***********************************************************************

local function hextobin(hbin)
  local bin = ""
  for pair in hbin:gmatch "(%x%x)" do
    bin = bin .. string.char(tonumber(pair,16))
  end
  return bin
end

-- ***********************************************************************

local function bintohex(bin)
  local hbin = ""
  for c in bin:gmatch(".") do
    hbin = hbin .. string.format("%02X",string.byte(c))
  end
  return hbin
end

-- ***********************************************************************

local function compare(a,b)
  if type(a) ~= type(b) then
    return false
  end
  
  if type(a) == 'table' then
    for name,value in pairs(a) do
      if not compare(value,b[name]) then
        return false
      end
    end
    for name,value in pairs(b) do
      if not compare(value,a[name]) then
        return false
      end
    end
    return true
  else
    if a ~= a and b ~= b then -- handle NaNs
      return true
    else
      return a == b
    end
  end
end

assert(compare({a=1,b=2},{b=2,a=1}))
assert(compare({1,2,3},{1,2,3}))

-- ***********************************************************************

local function test(ctype,hbinary,src,srcf,destf)
  local bin = hextobin(hbinary)
  local encoded
  
  if srcf ~= 'SKIP' then
    if srcf then
      encoded = srcf()
    else
      encoded = cbor.encode(src)
    end

    assertf(encoded == bin,"encoding for %s failed:\n%s\n%s",ctype,hbinary,bintohex(encoded))
  else
    print("SKIPPED encoding",ctype)
    encoded = bin
  end
  
  local rctype,decoded = cbor.decode(encoded)
  
  assertf(rctype == ctype,"decoding type failed: wanted %s got %s",ctype,rctype)
  
  if type(destf) == 'function' then
    assertf(destf(src,decoded),"decoding for %s is different",ctype)
  else
    assertf(compare(src,decoded),"decoding for %s is different",ctype)
  end
  
  return true
end

-- ***********************************************************************
-- values from RFC-7049
-- ***********************************************************************

test('UINT',"00",0)
test('UINT',"01",1)
test('UINT',"0A",10)
test('UINT',"17",23)
test('UINT',"1818",24)
test('UINT',"1819",25)
test('UINT',"1864",100)
test('UINT',"1903e8",1000)
test('UINT',"1a000f4240",1000000)
test('UINT',"1b000000e8d4a51000",1000000000000)
test('NINT',"20",-1)
test('NINT',"29",-10)
test('NINT',"3863",-100)
test('NINT',"3903E7",-1000)
test('half',"F90000",0.0,    function() return cbor.SIMPLE.half(0.0)  end)
test('half',"F98000",-0.0,   function() return cbor.SIMPLE.half(-0.0) end)
test('half',"F93C00",1.0,    function() return cbor.SIMPLE.half(1.0)  end)
test('half',"F93E00",1.5)
test('half',"F97BFF",65504.0,function() return cbor.SIMPLE.half(65504.0) end)
--test('single',"fa47c35000",100000.0, function() return cbor.SIMPLE.single(100000.0) end)
--test('single',"fa7f7fffff",3.4028234663852886e+38	, nil , true  , true)
--test('double',"fb7e37e43c8800759c",1.0e+300		, nil , false , true)
--test('half',"f90001",5.960464477539063e-8)
--test('half',"f90400",0.00006103515625)
--test('half',"f9c400",-4.0)
--test('double',"fbc010666666666666",-4.1)
--test('half',"f97c00",math.huge)
--test('half',"f97e00",0/0				, nil , false , true)
--test('half',"f9fc00",-math.huge)
--test('single',"fa7f800000",math.huge)
--test('single',"fa7fc00000",0/0				, nil , true  , true)
--test('single',"faff800000",-math.huge)
--test('double',"fb7ff0000000000000",math.huge)
--test('double',"fb7ff8000000000000",0/0			, nil , true  , true)
--test('double',"fbfff0000000000000",-math.huge)
--test('false',"F4",false)
--test('true',"F5",true)
--test('null',"F6",nil)
--test('undefined',"F7",nil,function() return cbor.SIMPLE.undefined() end)
test('SIMPLE',"F0",16,   function() return cbor.SIMPLE['16']()  end)
test('SIMPLE',"f818",24, function() return cbor.SIMPLE['24']()  end)
test('SIMPLE',"F8FF",255,function() return cbor.SIMPLE['255']() end)
test('_epoch',"c11a514b67b0",1363896240,
	function() return cbor.TAG._epoch(1363896240) end)
test('_epoch',"c1fb41d452d9ec200000",1363896240.5,
	function() return cbor.TAG._epoch(1363896240.5) end)
test('_tobase16',"d74401020304","\1\2\3\4", 	-- RFC wrong here
	function() return cbor.TAG._tobase16 "\1\2\3\4" end)
test('_cbor',"d818456449455446","dIETF",
	function() return cbor.TAG._cbor(cbor.TYPE.TEXT("IETF")) end)
test('_url',"d82076687474703a2f2f7777772e6578616d706c652e636f6d",
	"http://www.example.com",
	function() return cbor.TAG._url "http://www.example.com" end)
test('BIN',"40","",function() return cbor.TYPE.BIN("") end)
test('BIN',"4401020304","\1\2\3\4")
test('TEXT',"60","")
test('TEXT',"6161","a")
test('TEXT',"6449455446","IETF")
test('TEXT',"62225c",[["\]])
test('TEXT',"62c3bc","\195\188")
test('TEXT',"63e6b0b4","\230\176\180")
test('TEXT',"64f0908591","\240\144\133\145")
test('ARRAY',"80",{},function() return cbor.TYPE.ARRAY {} end)
test('ARRAY',"83010203",{1,2,3})
test('ARRAY',"8301820203820405",{ 1 , { 2 , 3 } , { 4 , 5 }})
test('ARRAY',"98190102030405060708090a0b0c0d0e0f101112131415161718181819",
	{ 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25 })
test('MAP',"A0",{})
test('MAP',"a201020304",{ [1] = 2 , [3] = 4},
	function()
	  return cbor5.encode(0xA0,2)
	      .. cbor.encode(1) .. cbor.encode(2)
	      .. cbor.encode(3) .. cbor.encode(4)
	end)
test('MAP',"a26161016162820203",{ a = 1 , b = { 2, 3 } })
test('ARRAY',"826161a161626163",{ "a" , { b = "c" }})
test('MAP',"a56161614161626142616361436164614461656145",
	{ a = 'A' , b = 'B' , c = 'C' , d = 'D' , e = 'E' },
	function() 
	  return cbor5.encode(0xA0,5)
	      .. cbor.encode "a" .. cbor.encode "A"
	      .. cbor.encode "b" .. cbor.encode "B"
	      .. cbor.encode "c" .. cbor.encode "C"
	      .. cbor.encode "d" .. cbor.encode "D"
	      .. cbor.encode "e" .. cbor.encode "E"
	end
	)
test('BIN',"5f42010243030405ff","\1\2\3\4\5",
	function() 
	  return cbor5.encode(0x40)
	      .. cbor.TYPE.BIN "\1\2"
	      .. cbor.TYPE.BIN "\3\4\5"
	      .. cbor.SIMPLE.__break()
	end)
test('TEXT',"7f657374726561646d696e67ff","streaming",
	function()
	  return cbor5.encode(0x60)
	      .. cbor.TYPE.TEXT("strea")
	      .. cbor.TYPE.TEXT("ming")
	      .. cbor.SIMPLE.__break()
	end)
test('ARRAY',"9fff",{},
	function()
	  return cbor.TYPE.ARRAY() 
	      .. cbor.SIMPLE.__break()
	end)
test('ARRAY',"9f018202039f0405ffff",{ 1 , { 2 , 3 } , { 4 , 5 }},
	function()
	  return cbor.TYPE.ARRAY()
	      .. cbor.encode(1)
	      .. cbor.encode { 2 , 3 }
	      .. cbor.TYPE.ARRAY()
	           .. cbor.encode(4)
	           .. cbor.encode(5)
	           .. cbor.SIMPLE.__break()
	      .. cbor.SIMPLE.__break()
	end)
test('ARRAY',"9f01820203820405ff",{ 1 , { 2 ,3 } , { 4 , 5 }},
	function()
	  return cbor.TYPE.ARRAY()
	      .. cbor.encode(1)
	      .. cbor.encode{ 2 , 3 }
	      .. cbor.encode{ 4 , 5 }
	      .. cbor.SIMPLE.__break()
	end)
test('ARRAY',"83018202039f0405ff",{ 1 , { 2 ,3 } , { 4 , 5 }},
	function()
	  return cbor.TYPE.ARRAY(3)
	      .. cbor.encode(1)
	      .. cbor.encode { 2, 3 }
	      .. cbor.TYPE.ARRAY()
	         .. cbor.encode(4)
	         .. cbor.encode(5)
	         .. cbor.SIMPLE.__break()
	end)
test('ARRAY',"83019F0203FF820405",{ 1 , { 2 ,3 } , { 4 , 5 }},
	function()
	  return cbor.TYPE.ARRAY(3)
	      .. cbor.encode(1)
	      .. cbor.TYPE.ARRAY()
	         .. cbor.encode(2)
	         .. cbor.encode(3)
	         .. cbor.SIMPLE.__break()
	      .. cbor.encode { 4 , 5 }
	end)
test('ARRAY',"9f0102030405060708090a0b0c0d0e0f101112131415161718181819ff",
	{ 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25 },
	function()
	  local res = cbor.TYPE.ARRAY()
	  for i = 1 , 25 do
	    res = res .. cbor.encode(i)
	  end
	  return res .. cbor.SIMPLE.__break()
	end)
test('MAP',"bf61610161629f0203ffff",{ a = 1 , b = { 2, 3 } },
	function()
	  return cbor.TYPE.MAP()
	      .. cbor.encode "a" .. cbor.encode(1)
	      .. cbor.encode "b" .. cbor.TYPE.ARRAY()
	      			 .. cbor.encode(2)
	      			 .. cbor.encode(3)
	      			 .. cbor.SIMPLE.__break()
	      .. cbor.SIMPLE.__break()
	end) 
test('ARRAY',"826161bf61626163ff",{ "a" , { b = "c" }},
	function()
	  return cbor.TYPE.ARRAY(2)
	      .. cbor.encode "a"
	      .. cbor.TYPE.MAP()
	         .. cbor.encode "b" .. cbor.encode "c"
	         .. cbor.SIMPLE.__break()
	end)
test('MAP',"bf6346756ef563416d7421ff",{ Fun = true , Amt = -2 },
	function()
	  return cbor.TYPE.MAP()
	      .. cbor.encode "Fun" .. cbor.SIMPLE['true']()
	      .. cbor.encode "Amt" .. cbor.encode(-2)
	      .. cbor.SIMPLE.__break()
	end)

-- ***********************************************************************
-- other tests
-- ***********************************************************************

test('TAG_1234567890',"DA499602D200",0,
	function() return cbor.TAG['1234567890'](0) end)

-- _stringref and _nthstring tests
-- http://cbor.schmorp.de/stringref

test('ARRAY',"d9010083a34472616e6b0445636f756e741901a1446e616d6548436f636b7461696ca3d819024442617468d81901190138d8190004a3d8190244466f6f64d819011902b3d8190004",
	{
	  {
	    name = 'Cocktail',
	    count = 417,
	    rank = 4,
	  },
	  {
	    rank = 4,
	    count = 312,
	    name = "Bath",
	  },
	  {
	    count = 691,
	    name = "Food",
	    rank = 4
	  },
	},'SKIP')

-- NOTE: in the 2nd example, the JSON array and the binary CBOR
-- representation don't match.  The JSON array here is fixed to match the
-- actual binary presented.

test('ARRAY',"d9010098204131433232324333333341344335353543363636433737374338383843393939436161614362626243636363436464644365656543666666436767674368686843696969436a6a6a436b6b6b436c6c6c436d6d6d436e6e6e436f6f6f4370707043717171437272724473737373d81901d8191743727272d8191818",
	{  
	  "1", "222", "333",   "4", "555", "666", "777", "888", "999",
	  "aaa", "bbb", "ccc", "ddd", "eee", "fff", "ggg", "hhh", "iii",
	  "jjj", "kkk", "lll", "mmm", "nnn", "ooo", "ppp", "qqq", "rrr",
	  "ssss" , "333", "qqq", "rrr", "ssss" 
	},'SKIP')

test('ARRAY',"d901008563616161d81900d90100836362626263616161d81901d901008263636363d81900d81900",
	{ 
	  "aaa" , "aaa" , 
	  { "bbb" , "aaa" , "aaa" } , 
	  { "ccc" , "ccc" } , 
	  "aaa" 
	},'SKIP')

-- _perlobj

test('_perlobj',"d81a826c4d793a3a4461746554696d651a00bc614e",
	{ "My::DateTime" , 12345678 },
	function() return cbor.TAG._perlobj { 'My::DateTime' , 12345678 } end)

-- _shareable and __sharedref
-- http://cbor.schmorp.de/value-sharing

test('ARRAY',"83d81c80d81d0080",{ {},{},{}},'SKIP')

test('ARRAY',"d81c81d81d00",{},
  'SKIP',
  function(_,v)
    assertf(type(v) == 'table',"_sharedref: wanted table got %s",type(v))
    assertf(#v == 1,"_sharedref: length bad %d",#v)
    assertf(v[1] == v,"_sharedref: not a reference")
    return true
  end)

-- _rational
-- http://peteroupc.github.io/CBOR/rational.html

test('_rational',"d81e820103",{ 1 , 3 },
	function() return cbor.TAG._rational { 1 , 3 } end)

-- _language
-- http://peteroupc.github.io/CBOR/langtags.html

test('_language',"d8268262656E6548656C6C6F",{ "en" , "Hello"},
	function() return cbor.TAG._language { "en" , "Hello" } end)
	
test('_language',"d8268262667267426F6E6A6F7572",{ "fr" , "Bonjour" },
	function() return cbor.TAG._language { "fr" , "Bonjour" } end)
