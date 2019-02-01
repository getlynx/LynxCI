#!/usr/bin/env python3

#import MySQLdb
import json, datetime, socket, re
from http.server import BaseHTTPRequestHandler, HTTPServer

WRITE_TO_DATABASE = False
WRITE_TO_CONSOLE  = True

class Singleton:
    def __init__(self, klass):
        self.klass = klass
        self.instance = None

    def __call__(self, *args, **kwds):
        if self.instance == None:
            self.instance = self.klass(*args, 
                **kwds)
        return self.instance


class S(BaseHTTPRequestHandler):
    def _set_response(self, code):
        self.server_version = 'Apache'
        self.sys_version = '2.0'
        self.send_response(code)
        self.end_headers()

    def do_POST(self):
        client_address = self.client_address[0]
        #print("client_address: {}".format(client_address))
        content_length = int(self.headers['Content-Length'])
        #print("Content-Length: {}".format(content_length))
        if content_length > 100: 
            print("content_length is to hight not allowed!")
            self._set_response(400)
            return False
        post_data = self.rfile.read(content_length)
        #print("post_data: {}".format(post_data))
        process_request(client_address, post_data)
        self._set_response(200)


@Singleton
class Database:
    """
    connection = None
    hostname = "0.0.0.0"
    username = "lynx"
    password = "HdmLdnQWvtVPWEas4DYBiUri"
    database = "lynx"
    def get_connection(self):
        if self.connection is not None:
            conn = self.connection
            return conn
        try:
            self.connection = MySQLdb.connect(self.hostname,
                self.username,
                self.password,
                self.database)
        except MySQLdb.Error as e:
            print("(mysql-conn.error): {}".format(e))
            return None
        else:
            return self.connection
    """

def store_request(data):

    ### CHECK HOST
    # Host must be less than 30 chars
    if len(data['host']) > 30:
        return False

    ### CHECK IP
    # Use socket to check for valid IP
    try: socket.inet_aton(data['ip'])
    except socket.error:
        return False

    ### CHECK HEIGHT
    # Height value must be at least 8 chars, between 0 and 10 million
    if len(str(data['height'])) > 8 \
    or int(data['height']) < 0 \
    or int(data['height']) > 10000000:
        return False

    ### CHECK WALLET
    # Value must be either 0 or 1 or it fails
    if int(data['wallet']) < 0 \
    or int(data['wallet']) > 1:
        return False

    # CHECK RPI
    # Value must be either 0 or 1 or it fails
    if int(data['RPI']) < 0 \
    or int(data['RPI']) > 1:
        return False

    query = '''
        INSERT INTO lynx
            (
                `host`,
                `ip`,
                `height`,
                `wallet`,
                `rpi`,
            )
        VALUES
            ('%s', '%s', '%s', '%s', '%s')
    ''' % (
            data['host'],
            data['ip'],
            data['height'],
            data['wallet'],
            data['RPI']
        )

    if WRITE_TO_CONSOLE:
        print("%s | %s | Wallet:%s | Pi:%s | %s" % (data['ip'], data['height'], data['wallet'], data['RPI'], data['host']) )

    """
    if WRITE_TO_DATABASE:

        try:
            db = Database().get_connection()
            print("**db: {}".format(db))
            cursor = db.cursor() 
            cursor.execute(query)
            db.commit()
            cursor.close()
        except MySQLdb.Error as e:
            print("(mysql-error): {}".format(e))
            db.ping(True)
            return False
        else:
            return True
    """

def process_request(ip, data):
    try:
        data = data.decode('utf8')
        data = json.loads(data)
    except ValueError:
        print("(json): invalid request!")
        return False
    data["ip"] = ip
    if not 'height' in data:
        print("(key::height): not found!")
        return False
    height = str(data["height"])
    if not height.isdigit():
        print("(key::height): not number!")
        return False
    try:
        socket.inet_aton(data["ip"])
    except:
        print("(key::ip): invalid!")
        return False
    ret = store_request(data)
    return ret


def run_http_server(server_class=HTTPServer, handler_class=S, port=8080):
    print('Starting httpd...\n')

    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()

    print('Stopping httpd...\n')

if __name__ == '__main__': 
    run_http_server()
