# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

import contextlib
import os
import subprocess

from .tester import Tester
from .util import run_cmd, log


class GoTester(Tester):
    PRODUCER = True
    CONSUMER = True
    FLIGHT_SERVER = True
    FLIGHT_CLIENT = True

    # FIXME(sbinet): revisit for Go modules
    HOME = os.getenv('HOME', '~')
    GOPATH = os.getenv('GOPATH', os.path.join(HOME, 'go'))
    GOBIN = os.environ.get('GOBIN', os.path.join(GOPATH, 'bin'))

    GO_INTEGRATION_EXE = os.path.join(GOBIN, 'arrow-json-integration-test')
    STREAM_TO_FILE = os.path.join(GOBIN, 'arrow-stream-to-file')
    FILE_TO_STREAM = os.path.join(GOBIN, 'arrow-file-to-stream')

    FLIGHT_SERVER_CMD = [
        os.path.join(GOBIN, 'arrow-flight-integration-server')]
    FLIGHT_CLIENT_CMD = [
        os.path.join(GOBIN, 'arrow-flight-integration-client'),
        '-host', 'localhost']

    name = 'Go'

    def _run(self, arrow_path=None, json_path=None, command='VALIDATE'):
        cmd = [self.GO_INTEGRATION_EXE]

        if arrow_path is not None:
            cmd.extend(['-arrow', arrow_path])

        if json_path is not None:
            cmd.extend(['-json', json_path])

        cmd.extend(['-mode', command])

        if self.debug:
            log(' '.join(cmd))

        run_cmd(cmd)

    def validate(self, json_path, arrow_path, quirks=None):
        return self._run(arrow_path, json_path, 'VALIDATE')

    def json_to_file(self, json_path, arrow_path):
        return self._run(arrow_path, json_path, 'JSON_TO_ARROW')

    def stream_to_file(self, stream_path, file_path):
        cmd = [self.STREAM_TO_FILE, '<', stream_path, '>', file_path]
        self.run_shell_command(cmd)

    def file_to_stream(self, file_path, stream_path):
        cmd = [self.FILE_TO_STREAM, file_path, '>', stream_path]
        self.run_shell_command(cmd)

    @contextlib.contextmanager
    def flight_server(self, scenario_name=None):
        cmd = self.FLIGHT_SERVER_CMD + ['-port=0']
        if scenario_name:
            cmd = cmd + ['-scenario', scenario_name]
        if self.debug:
            log(' '.join(cmd))
        server = subprocess.Popen(cmd,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)

        try:
            output = server.stdout.readline().decode()
            if not output.startswith("Server listening on localhost:"):
                server.kill()
                out, err = server.communicate()
                raise RuntimeError(
                    "Flight-Go server did not start properly, "
                    "stdout: \n{}\n\nstderr:\n{}\n"
                    .format(output + out.decode(), err.decode())
                )
            port = int(output.split(":")[1])
            yield port
        finally:
            server.kill()
            server.wait(5)

    def flight_request(self, port, json_path=None, scenario_name=None):
        cmd = self.FLIGHT_CLIENT_CMD + [
            '-port=' + str(port),
        ]
        if json_path:
            cmd.extend(('-path', json_path))
        elif scenario_name:
            cmd.extend(('-scenario', scenario_name))
        else:
            raise TypeError("Must provide one of json_path or scenario_name")

        if self.debug:
            log(' '.join(cmd))
        run_cmd(cmd)
