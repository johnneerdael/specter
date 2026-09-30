# Strict JSON validator. Emits path<TAB>type<TAB>raw scalar; containers emit type.
# No decoding of property names: escaped names are refused, not misinterpreted.
{ input = input $0 "\n"; if (length(input) > 2097152) { bad=1; exit 2 } }
END {
  pos = 1
  value("")
  space()
  if (bad || pos <= length(input)) exit 2
  printf "%s", output
}
function space() { while (substr(input,pos,1) ~ /[ \t\r\n]/ && pos <= length(input)) pos++ }
function fail() { bad=1; pos=length(input)+1 }
function string(   begin,c,esc,h) {
  begin=pos++
  while (pos <= length(input)) {
    c=substr(input,pos++,1)
    if (c == "\"") return substr(input,begin,pos-begin)
    if (c ~ /[[:cntrl:]]/) { fail(); return "" }
    if (c == "\\") {
      esc=substr(input,pos++,1)
      if (esc == "u") {
        h=substr(input,pos,4)
        if (length(h)!=4 || h ~ /[^0-9a-fA-F]/) { fail(); return "" }
        pos+=4
      } else if (esc !~ /^["\\\/bfnrt]$/) { fail(); return "" }
    }
  }
  fail(); return ""
}
function emit(path,type,raw) { output=output (path=="" ? "/" : path) "\t" type "\t" raw "\n" }
function value(path,   c,key,k,idx,raw,begin) {
  if (length(path) > 2048) { fail();return }
  space(); c=substr(input,pos,1)
  if (c=="{") {
    emit(path,"object","");pos++;space()
    if (substr(input,pos,1)=="}") { pos++;return }
    while (!bad) {
      if (substr(input,pos,1)!="\"") { fail();return }
      raw=string()
      # Ambiguous/escaped path components cannot be handled safely.
      key=substr(raw,2,length(raw)-2)
      if (key ~ /[\\\/\t]/) { fail();return }
      k=path "/" key
      if (k in keys) { fail();return }
      keys[k]=1
      space()
      if (substr(input,pos++,1)!=":") { fail();return }
      value(k);space();c=substr(input,pos++,1)
      if(c=="}") return
      if(c!=",") { fail();return }
      space()
    }
  } else if(c=="[") {
    emit(path,"array","");pos++;space();idx=0
    if(substr(input,pos,1)=="]") { pos++;return }
    while(!bad) {
      value(path "/" idx++);space();c=substr(input,pos++,1)
      if(c=="]") return
      if(c!=",") { fail();return }
      space()
    }
  } else if(c=="\"") {
    raw=string();emit(path,"string",raw)
  } else {
    begin=pos
    while(pos<=length(input) && substr(input,pos,1) !~ /[ \t\r\n,\]}]/) pos++
    raw=substr(input,begin,pos-begin)
    if(raw=="true" || raw=="false") emit(path,"boolean",raw)
    else if(raw=="null") emit(path,"null",raw)
    else if(raw ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) emit(path,"number",raw)
    else fail()
  }
}
