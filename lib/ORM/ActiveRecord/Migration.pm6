
use ORM::ActiveRecord::DB;
use ORM::ActiveRecord::X;

class Migration is export {
  has DB $!db;
  has @.foreign-keys;

  submethod DESTROY {
    $!db = Nil;
  }

  submethod BUILD {
    $!db = DB.new;
  }

  method create-table(Str:D $table, @params) {
    self.do-create-table($table, @params);
    self.do-add-primary-key($table);
    self.do-add-foreign-keys($table);
  }

  method do-add-foreign-keys(Str:D $table) {
    for @!foreign-keys {
      my $sql = qq:to/SQL/;
        ALTER TABLE $table
        ADD CONSTRAINT fk_{$_}_id
        FOREIGN KEY ({$_}_id)
        REFERENCES {$_ ~ 's'}(id)
        SQL

      $!db.exec($sql);
    }

    @!foreign-keys = [];
  }

  method do-add-primary-key(Str:D $table) {
    my $sql = qq:to/SQL/;
      ALTER TABLE $table
      ADD CONSTRAINT {$table}_pkey PRIMARY KEY (id);
      SQL

    $!db.exec($sql);
  }

  method do-create-table(Str:D $table, @params) {
    my $fields = self.build-fields(@params);

    my $sql = qq:to/SQL/;
      CREATE TABLE $table ( id SERIAL, $fields )
      SQL

    $!db.exec($sql);
  }

  method build-fields(@params) {
    my @fields;

    for @params {
      my $name = $_.keys.first;
      my $field_name = $name ~~ Pair ?? $name.keys.first !! $name;

      my $type = '';
      my $limit = '';
      my $default = '';
      my $null = '';

      for $_{$name}.keys -> $attr {
        my $value = $_{$name}{$attr};

        given $attr {
          when 'string' { $type = 'VARCHAR' }
          when 'text' { $type = 'TEXT' }
          when 'integer' { $type = 'INTEGER' }
          when 'boolean' { $type = 'BOOL' }
          when 'limit' { $limit = '(' ~ $value ~ ')' }
          when 'default' { $default = $value }
          when 'null' { $null = $value }
          when 'reference' {
            @!foreign-keys.push($field_name);
            $type = 'INTEGER';
            $field_name = $field_name ~ '_id';
          }
          default { say 'unknown attr: ' ~ $attr ~ ' ' ~ $value; die }
        }
      }

      if $type ~~ 'BOOL' {
        given $default {
          when 'True' { $default = " DEFAULT 't'" }
          when 'False' { $default = " DEFAULT 'f'" }
          default { $default = '' }
        }
      }

      if $type ~~ /(INTEGER|VARCHAR)/ {
        given $null {
          when 'True' { $null = ' NULL' }
          when 'False' { $null = ' NOT NULL' }
          default { $null = '' }
        }
      }

      if $type ~~ 'INTEGER' {
        given $default {
          when /\d+/ { $default = " DEFAULT $default" }
          default { $default = '' }
        }
      }

      @fields.push($field_name ~ ' ' ~ $type ~ $limit ~ $default ~ $null);
    }

    @fields.join(', ').trim;
  }

  method add-column(Str:D $table, Pair:D $params) {
    my $fields = self.build-fields([$params]);

    my $sql = qq:to/SQL/;
      ALTER TABLE $table
      ADD COLUMN $fields
      SQL

    $!db.exec($sql);
  }

  method add-index(Str:D $table, |params) {
    my $params = params;
    my $field = params.keys.first;
    my $name = $table ~ '_' ~ $field ~ '_idx';
    my $unique = '';

    if !params{$field} {
      my ($keys, $values) = params[0].kv;

      if $keys ~~ List {
        $params = $values;
        $name = $table ~ '_' ~ $keys.join('_') ~ '_idx';
        $field = $keys.join(', ');
      }
    }

    for $params -> $param {
      given $param {
        when /:i unique/ { $unique = ' UNIQUE ' }
        when .so {}
        default { say 'Unknown index param: ' ~ $param; die }
      }
    }

    my $sql = qq:to/SQL/;
      CREATE $unique INDEX $name
      ON $table ($field)
      SQL

    $!db.exec($sql);
  }

  method drop-table(Str:D $table) {
    my $sql = qq:to/SQL/;
      DROP TABLE $table
      SQL

    $!db.exec($sql);
  }

  method remove-column(Str:D $table, |params) {
    my $field = params.keys.first;

    my $sql = qq:to/SQL/;
      ALTER TABLE $table
      DROP COLUMN $field
      SQL

    $!db.exec($sql);
  }

  method remove-index(Str:D $table, |params) {
    my $field = params.keys.first;
    my $name = $table ~ '_' ~ $field ~ '_idx';

    my $sql = qq:to/SQL/;
      DROP INDEX $name
      SQL

    $!db.exec($sql);
  }

  method irreversible-migration {
    die X::IrreversibleMigration.new;
  }
}
