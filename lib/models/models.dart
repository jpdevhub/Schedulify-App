// Domain models mirroring the Supabase schema

class Profile {
  final String id;
  final String role; // super_admin | admin | faculty | student
  final String firstName;
  final String lastName;
  final String? department;
  final String? employeeId;
  final String? rollNumber;
  final String? batch;
  final String? semester;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.department,
    this.employeeId,
    this.rollNumber,
    this.batch,
    this.semester,
    this.phone,
    this.avatarUrl,
    required this.isActive,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'],
        role: j['role'],
        firstName: j['first_name'],
        lastName: j['last_name'],
        department: j['department'],
        employeeId: j['employee_id'],
        rollNumber: j['roll_number'],
        batch: j['batch'],
        semester: j['semester'],
        phone: j['phone'],
        avatarUrl: j['avatar_url'],
        isActive: j['is_active'] ?? true,
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
        'department': department,
        'employee_id': employeeId,
        'roll_number': rollNumber,
        'batch': batch,
        'semester': semester,
        'phone': phone,
        'avatar_url': avatarUrl,
        'is_active': isActive,
      };
}

class Department {
  final String id;
  final String name;
  final String code;
  final String? headId;
  final String? description;
  final DateTime createdAt;
  Profile? head;

  Department({
    required this.id,
    required this.name,
    required this.code,
    this.headId,
    this.description,
    required this.createdAt,
    this.head,
  });

  factory Department.fromJson(Map<String, dynamic> j) {
    final d = Department(
      id: j['id'],
      name: j['name'],
      code: j['code'],
      headId: j['head_id'],
      description: j['description'],
      createdAt: DateTime.parse(j['created_at']),
    );
    if (j['profiles'] != null) {
      d.head = Profile.fromJson(j['profiles']);
    }
    return d;
  }
}

class Course {
  final String id;
  final String name;
  final String code;
  final int credits;
  final String? departmentId;
  final String? semester;
  final String courseType;
  final bool isElective;
  final String? description;
  final DateTime createdAt;
  Department? department;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    this.departmentId,
    this.semester,
    required this.courseType,
    required this.isElective,
    this.description,
    required this.createdAt,
    this.department,
  });

  factory Course.fromJson(Map<String, dynamic> j) {
    final c = Course(
      id: j['id'],
      name: j['name'],
      code: j['code'],
      credits: j['credits'] ?? 3,
      departmentId: j['department_id'],
      semester: j['semester'],
      courseType: j['course_type'] ?? 'theory',
      isElective: j['is_elective'] ?? false,
      description: j['description'],
      createdAt: DateTime.parse(j['created_at']),
    );
    if (j['departments'] != null) {
      c.department = Department.fromJson(j['departments']);
    }
    return c;
  }
}

class Classroom {
  final String id;
  final String name;
  final int? capacity;
  final String roomType;
  final String? building;
  final int? floor;
  final bool isAvailable;

  Classroom({
    required this.id,
    required this.name,
    this.capacity,
    required this.roomType,
    this.building,
    this.floor,
    required this.isAvailable,
  });

  factory Classroom.fromJson(Map<String, dynamic> j) => Classroom(
        id: j['id'],
        name: j['name'],
        capacity: j['capacity'],
        roomType: j['room_type'] ?? 'lecture',
        building: j['building'],
        floor: j['floor'],
        isAvailable: j['is_available'] ?? true,
      );
}

class Timetable {
  final String id;
  final String name;
  final String? departmentId;
  final String academicYear;
  final String semester;
  final bool isActive;
  final String status; // draft | published | archived
  final String? generatedBy;
  final DateTime createdAt;
  Department? department;

  Timetable({
    required this.id,
    required this.name,
    this.departmentId,
    required this.academicYear,
    required this.semester,
    required this.isActive,
    required this.status,
    this.generatedBy,
    required this.createdAt,
    this.department,
  });

  factory Timetable.fromJson(Map<String, dynamic> j) {
    final t = Timetable(
      id: j['id'],
      name: j['name'],
      departmentId: j['department_id'],
      academicYear: j['academic_year'],
      semester: j['semester'],
      isActive: j['is_active'] ?? false,
      status: j['status'] ?? 'draft',
      generatedBy: j['generated_by'],
      createdAt: DateTime.parse(j['created_at']),
    );
    if (j['departments'] != null) {
      t.department = Department.fromJson(j['departments']);
    }
    return t;
  }
}

class TimetableEntry {
  final String id;
  final String timetableId;
  final String? courseId;
  final String? facultyId;
  final String? classroomId;
  final int dayOfWeek; // 0=Sun, 1=Mon...6=Sat
  final String startTime; // HH:mm:ss
  final String endTime;
  final String sessionType; // lecture | lab | tutorial
  final String? studentGroup;
  Course? course;
  Profile? faculty;
  Classroom? classroom;

  TimetableEntry({
    required this.id,
    required this.timetableId,
    this.courseId,
    this.facultyId,
    this.classroomId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.sessionType,
    this.studentGroup,
    this.course,
    this.faculty,
    this.classroom,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> j) {
    final e = TimetableEntry(
      id: j['id'],
      timetableId: j['timetable_id'],
      courseId: j['course_id'],
      facultyId: j['faculty_id'],
      classroomId: j['classroom_id'],
      dayOfWeek: j['day_of_week'],
      startTime: j['start_time'],
      endTime: j['end_time'],
      sessionType: j['session_type'] ?? 'lecture',
      studentGroup: j['student_group'],
    );
    if (j['courses'] != null) e.course = Course.fromJson(j['courses']);
    if (j['profiles'] != null) e.faculty = Profile.fromJson(j['profiles']);
    if (j['classrooms'] != null) e.classroom = Classroom.fromJson(j['classrooms']);
    return e;
  }
}

class AppNotification {
  final String id;
  final String? userId;
  final String? targetRole;
  final String title;
  final String message;
  final String type; // info|warning|success|error|announcement
  final String priority;
  final bool isRead;
  final String? actionUrl;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    this.userId,
    this.targetRole,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    this.actionUrl,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        userId: j['user_id'],
        targetRole: j['target_role'],
        title: j['title'],
        message: j['message'],
        type: j['type'],
        priority: j['priority'] ?? 'normal',
        isRead: j['is_read'] ?? false,
        actionUrl: j['action_url'],
        createdAt: DateTime.parse(j['created_at']),
      );
}

class RegisteredCollege {
  final String id;
  final String collegeId;
  final String collegeName;
  final String? contactEmail;
  final String? supabaseUrl;
  final String? anonKey;
  final bool groqConfigured;
  final String plan;
  final String status;

  RegisteredCollege({
    required this.id,
    required this.collegeId,
    required this.collegeName,
    this.contactEmail,
    this.supabaseUrl,
    this.anonKey,
    required this.groqConfigured,
    required this.plan,
    required this.status,
  });

  factory RegisteredCollege.fromJson(Map<String, dynamic> j) => RegisteredCollege(
        id: j['id'],
        collegeId: j['college_id'],
        collegeName: j['college_name'],
        contactEmail: j['contact_email'],
        supabaseUrl: j['supabase_url'],
        anonKey: j['anon_key'],
        groqConfigured: j['groq_configured'] ?? false,
        plan: j['plan'] ?? 'free',
        status: j['status'] ?? 'active',
      );
}
