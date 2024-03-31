const std = @import("std");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const input = std.io.getStdIn().reader();

    var game = Game.fromAllocator(std.heap.page_allocator);
    const winnerGame: ?Game.Player = while (game.num_moves < 9) {
        const winner = game.checkWin();
        if (winner) |w| break w;
        try stdout.print("Checking win\n", .{});
        try game.renderBoard(&stdout);

        // take input:
        try stdout.print("Enter a move: \n", .{});
        try bw.flush();
        const line = try input.readUntilDelimiterOrEofAlloc(game.allocator, '\n', 1024);
        if (line) |l| {
            const line_parsed = std.fmt.parseInt(u8, l, 10) catch {
                try stdout.print("Invalid input\n", .{});
                continue;
            };

            if (line_parsed < 1 or line_parsed > 9) {
                try stdout.print("Invalid input\n. Try a number between 1 and 9\n", .{});
            }

            const move = Game.Move.fromNumber(game.next_turn, line_parsed);
            try game.playTurn(move);

            defer bw.flush() catch {};
            defer std.heap.page_allocator.free(l);
        }
    } else null;

    if (winnerGame) |winner| {
        switch (winner) {
            .one => try stdout.print("The winner is {s}\n", .{"X"}),
            .two => try stdout.print("The winner is {s}\n", .{"O"}),
        }
    } else {
        try stdout.print("It's a tie!\n", .{});
    }

    try bw.flush(); // don't forget to flush!
}

pub const Game = struct {
    allocator: std.mem.Allocator,
    next_turn: Player = .one,
    board: [3][3]?Player = [_][3]?Player{ [_]?Player{ null, null, null }, [_]?Player{ null, null, null }, [_]?Player{ null, null, null } },
    num_moves: usize = 0,

    const Player = enum { one, two };

    const PlayerName = union(Player) {
        one: []const u8,
        two: []const u8,
    };

    pub const Move = struct {
        player: Player,
        coord: [2]u8,

        pub fn fromNumber(player: Player, number: u8) Move {
            const coord = switch (number) {
                1 => [2]u8{ 0, 0 },
                2 => [2]u8{ 0, 1 },
                3 => [2]u8{ 0, 2 },
                4 => [2]u8{ 1, 0 },
                5 => [2]u8{ 1, 1 },
                6 => [2]u8{ 1, 2 },
                7 => [2]u8{ 2, 0 },
                8 => [2]u8{ 2, 1 },
                9 => [2]u8{ 2, 2 },
                else => unreachable,
            };
            return .{ .player = player, .coord = coord };
        }
    };

    pub fn fromAllocator(allocator: std.mem.Allocator) Game {
        return .{ .allocator = allocator };
    }

    pub fn playTurn(self: *Game, move: Move) !void {
        if (self.board[move.coord[0]][move.coord[1]]) |_| {
            return error.InvalidMove;
        }

        self.board[move.coord[0]][move.coord[1]] = move.player;
        self.next_turn = switch (self.next_turn) {
            .one => .two,
            .two => .one,
        };

        self.num_moves += 1;
    }

    pub fn renderBoard(self: *const Game, stdout: anytype) !void {
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            var j: usize = 0;
            while (j < 3) : (j += 1) {
                const grid: u8 = Game.getCharacter(&self.board[i][j]);
                try stdout.print("{c} ", .{grid});
                if (j < 2) {
                    try stdout.print("|", .{});
                }
            }
            if (i < 2) {
                try stdout.print("\n--------\n", .{});
            } else {
                try stdout.print("\n", .{});
            }
        }
    }

    pub fn checkWin(self: *const Game) ?Player {
        // row check
        for (self.board) |row| {
            if (row[0] != null and row[0] == row[1] and row[1] == row[2]) {
                return row[0];
            }
        }

        // column check
        for (0..3) |i| {
            if (self.board[0][i] != null and self.board[0][i] == self.board[1][i] and self.board[1][i] == self.board[2][i]) {
                return self.board[0][i];
            }
        }

        // diagonal check
        if (self.board[0][0] != null and self.board[0][0] == self.board[1][1] and self.board[1][1] == self.board[2][2]) {
            return self.board[0][0];
        }
        if (self.board[0][2] != null and self.board[0][2] == self.board[1][1] and self.board[1][1] == self.board[2][0]) {
            return self.board[0][2];
        }

        return null;
    }

    fn getCharacter(input: *const ?Player) u8 {
        if (input.*) |player| {
            switch (player) {
                .one => return 'X',
                .two => return 'O',
            }
        } else {
            return ' ';
        }
    }
};

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
