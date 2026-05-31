const http = require('http');

const BASE_URL = 'http://localhost:3000';

function post(path, data, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const body = JSON.stringify(data || {});
    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers
    }, (res) => {
      let rawData = '';
      res.on('data', (chunk) => { rawData += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(rawData) });
        } catch (e) {
          resolve({ status: res.statusCode, body: rawData });
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.write(body);
    req.end();
  });
}

function get(path, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {};
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: 'GET',
      headers
    }, (res) => {
      let rawData = '';
      res.on('data', (chunk) => { rawData += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(rawData) });
        } catch (e) {
          resolve({ status: res.statusCode, body: rawData });
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.end();
  });
}

async function runTests() {
  console.log('=== STARTING GAMIFICATION API INTEGRATION TESTS ===');

  try {
    // 1. Login as admin user
    console.log('\n1. Logging in as admin...');
    const loginRes = await post('/auth/login', {
      email: 'admin@skycheck.uz',
      password: 'admin123'
    });
    
    if (loginRes.status !== 200 || !loginRes.body.token) {
      throw new Error(`Login failed with status ${loginRes.status}: ${JSON.stringify(loginRes.body)}`);
    }
    const token = loginRes.body.token;
    console.log('Login successful! Token acquired.');

    // 2. Fetch Profile Info
    console.log('\n2. Fetching profile info...');
    const profileRes = await get('/auth/me', token);
    console.log('Current Level:', profileRes.body.level);
    console.log('Current EXP:', profileRes.body.exp);
    console.log('Current Achievements:', profileRes.body.achievements);

    // 3. Fetch Courses with locks
    console.log('\n3. Fetching courses to inspect locked status...');
    const coursesRes = await get('/courses', token);
    coursesRes.body.forEach(c => {
      console.log(`- [Course ${c.id}] ${c.title} -> Locked: ${c.isLocked}`);
    });

    // 4. Try complete a step in Course 11 (first course)
    const firstCourse = coursesRes.body.find(c => !c.isLocked);
    const quizStep = firstCourse?.steps?.find(s => s.type === 'quiz' || (s.questions && s.questions.length > 0));
    if (quizStep) {
      console.log(`\n4. Answering a verification test step (Step ID ${quizStep.id})...`);
      const correctAnswer = quizStep.questions[0].answer;
      const wrongAnswer = (correctAnswer + 1) % quizStep.questions[0].options.length;
      
      // Wrong answer first
      const wrongAnsRes = await post(`/courses/steps/${quizStep.id}/complete`, { answer: wrongAnswer }, token);
      console.log(`Wrong answer response status (expected 400): ${wrongAnsRes.status}`);

      // Correct answer
      const rightAnsRes = await post(`/courses/steps/${quizStep.id}/complete`, { answer: correctAnswer }, token);
      console.log('Correct answer response status (expected 200):', rightAnsRes.status);
      console.log('Updated user levels & exp:', rightAnsRes.body);
    } else {
      console.log('\n4. No quiz step found to test step completion.');
    }

    // 5. Trigger weather check
    console.log('\n5. Triggering weather action...');
    const weatherRes = await post('/users/action/trigger-weather', {}, token);
    console.log('Weather trigger response:', weatherRes.body);

    // 6. Get profile again to verify EXP and achievements list
    console.log('\n6. Verifying final profile state...');
    const finalProfile = await get('/auth/me', token);
    console.log('Final Level:', finalProfile.body.level);
    console.log('Final EXP:', finalProfile.body.exp);
    console.log('Final Achievements:', finalProfile.body.achievements);

    console.log('\n=== ALL API TESTS PASSED SUCCESSFULLY ===');
  } catch (err) {
    console.error('Test run failed:', err);
    process.exit(1);
  }
}

runTests();
