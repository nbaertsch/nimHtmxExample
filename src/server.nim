## Following along with [FULL Introduction to HTMX Using Golang](https://www.youtube.com/watch?v=x7v6SNIgJpE&t=754s)

import mummy, mummy/routers, mummy/multipart
import mustache
import locks, tables, strutils, sequtils
import mustachepkg/values # for debuging mustache context with `.castStr`

type Contact = object
    name: string
    email: string

# needed for mustache
proc castValue(value: Contact): Value =
    let newValue = new(Table[string, Value])
    result = Value(kind: vkTable, vTable: newValue)
    newValue["name"] = value.name.castValue
    newValue["email"] = value.email.castValue

proc castValue*[T](value: seq[T]): Value =
    Value(kind: vkSeq, vSeq: value.mapIt(it.castValue))

#[
proc castValue[T](value: seq[T]): Value =
    var newValue = newSeq[Value](value.len)
    result = Value(kind: vkSeq, vSeq: newValue)
    for v in value:
        newValue.add(v.castValue())
]#

var count = 0
var contacts: seq[Contact]
var contactsLock: Lock; initLock(contactsLock)

proc parsePostParams(body: string): Table[string, string] =
    var assignments = body.split("&")
    for assignment in assignments:
        let keyVal = assignment.split("=")
        result[keyVal[0]] = keyVal[1]

proc countPostHandler(request: Request) =
    var headers: HttpHeaders
    #headers["Content-Type"] = "text/plain"
    count+=1
    let c = newContext(searchDirs = @["./templates"])
    c["count"] = count
    request.respond(200, headers, "Count: {{ count }}".render(c))

proc countGetHandler(request: Request) =
    var headers: HttpHeaders
    #headers["Content-Type"] = "text/plain"
    let c = newContext(searchDirs = @["./templates"])
    c["count"] = count
    request.respond(200, headers, "{{ >count }}".render(c))

proc contactsPostHandler(request: Request) {.gcsafe.} =
    var headers: HttpHeaders
    #headers["Content-Type"] = "text/plain"
    let c = newContext(searchDirs = @["./templates"])
    let params = request.body.parsePostParams()
    var resp: string
    withLock(contactsLock):
        {.gcsafe.}:
            contacts.add(
                Contact(
                    name: params["name"],
                    email: params["email"]
                )
            )
            c["contacts"] = contacts
            echo contacts
            echo c["contacts"].castStr
            resp = "{{ >display }}".render(c)
    request.respond(200, headers, resp)

proc indexGetHandler(request: Request) =
    var headers: HttpHeaders
    let c = newContext(searchDirs = @["./templates"])
    #headers["Content-Type"] = "text/plain"
    request.respond(200, headers, "{{ >index }}".render(c))


when isMainModule:
    var router: Router
    router.get("/count", countGetHandler)
    router.post("/count", countPostHandler)

    router.get("/", indexGetHandler)
    router.post("/contacts", contactsPostHandler)

    let server = newServer(router)
    echo "Serving on http://localhost:8080"
    echo "Counter on http://localhost:8080/count"
    server.serve(Port(8080))