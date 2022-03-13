requires "Hash::Flatten";
requires "IO::Handle";
requires "IO::String";
requires "JSON::Path";
requires "JSON::PP";
requires "List::MoreUtils";
requires "Moo";
requires "MooX::Options";
requires "Pod::Usage";
requires "Text::CSV";

on "test" => sub {
   requires "Test::More";
};
