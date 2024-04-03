## Following along with [FULL Introduction to HTMX Using Golang](https://www.youtube.com/watch?v=x7v6SNIgJpE&t=754s)

import mummy, mummy/routers, mummy/multipart
import mustache
import locks, tables, strutils, sequtils
import mustachepkg/values # for debuging mustache context with `.castStr`
import os
import filetype

type Contact = object
    id: int
    name: string
    email: string

# needed for mustache
proc castValue(value: Contact): Value =
    let newValue = new(Table[string, Value])
    result = Value(kind: vkTable, vTable: newValue)
    newValue["name"] = value.name.castValue
    newValue["email"] = value.email.castValue
    newValue["id"] = value.id.castValue

# why is this not available from mustache pkg? 
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
var id = 0
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
    withLock(contactsLock):
        {.gcsafe.}:
            for contact in contacts:
                if params["email"] == contact.email:
                    c["error"] = "Duplicate email entered!"
                    request.respond(422, headers, "{{ >contacts-form }}".render(c))
                    return

            contacts.add(
                Contact(
                    name: params["name"],
                    email: params["email"],
                    id: id
                )
            )
            c["id"] = id
            c["name"] = params["name"]
            c["email"] = params["email"]
            id += 1
            request.respond(200, headers, "{{ >contacts-form }}\n{{ >contact-display_oob }}".render(c))

proc contactsDeleteHandler(request: Request) {.gcsafe.} =
    os.sleep(1000) # 3s sleep for showing off hx-indicator and hx-swap-delay
    var headers: HttpHeaders
    let c = newContext(searchDirs = @["./templates"])
    let id = request.pathParams["id"].parseInt()
    withLock(contactsLock):
        {.gcsafe.}:
            for i in contacts.low..contacts.high:
                if contacts[i].id == id:
                    contacts.delete(i)
                    break
    request.respond(200, headers)

proc indexGetHandler(request: Request) =
    var headers: HttpHeaders
    let c = newContext(searchDirs = @["./templates"])
    #headers["Content-Type"] = "text/plain"
    c["count"] = count
    withLock(contactsLock):
        {.gcsafe.}:
            c["contacts"] = contacts
    request.respond(200, headers, "{{ >index }}".render(c))

proc staticFileHandler(serveDir: string): RequestHandler =
    return proc(request: Request) =
        var headers: HttpHeaders
        let filePath = serveDir & request.pathParams["file"]
        let fileContents = readFile(filePath)
        let fileSize = getFileSize(filePath)

        headers["Content-Type"] = matchFile(filePath).mime.value

        # smart folks cache these things...
        request.respond(200, headers, fileContents)

when isMainModule:
    var router: Router
    
    router.get("/", indexGetHandler)
    router.get("/static/@file", staticFileHandler("./static/"))
    router.get("/images/@file", staticFileHandler("./static/images/"))
    router.get("/css/@file", staticFileHandler("./static/css/"))

    router.get("/count", countGetHandler)
    router.post("/count", countPostHandler)

    router.post("/contacts", contactsPostHandler)
    router.delete("/contacts/@id", contactsDeleteHandler)

    let server = newServer(router)
    echo "Serving on http://localhost:8080"
    echo "Counter on http://localhost:8080/count"
    server.serve(Port(8080))