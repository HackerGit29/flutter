import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/user.dart';

void main() {
  group('User', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123', 'email': 'test@test.com',
        'role': 'admin', 'status': 'active',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      final user = User.fromJson(json);
      expect(user.role, Role.admin);
      expect(user.isAdmin, true);
      expect(user.isSuspended, false);
    });

    test('isSuspended returns true for suspended users', () {
      final user = User(
        id: '1', email: 'a@b.com', role: Role.user,
        status: UserStatus.suspended, createdAt: DateTime.now(),
      );
      expect(user.isSuspended, true);
    });

    test('copyWith preserves fields', () {
      final user = User(
        id: '1', email: 'a@b.com', role: Role.user,
        status: UserStatus.active, createdAt: DateTime.now(),
      );
      final updated = user.copyWith(role: Role.admin);
      expect(updated.role, Role.admin);
      expect(updated.email, 'a@b.com');
      expect(updated.id, '1');
    });

    test('toJson produces valid map', () {
      final user = User(
        id: '1', email: 'a@b.com', role: Role.user,
        status: UserStatus.active, createdAt: DateTime.utc(2026, 1, 1),
      );
      final json = user.toJson();
      expect(json['id'], '1');
      expect(json['role'], 'user');
      expect(json['status'], 'active');
    });
  });
}
