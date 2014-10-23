package Gtk2::Ex::RecordsFilter;

use warnings;
use strict;

=head1 NAME

Gtk2::Ex::RecordsFilter - A high level widget to browse reasonably large amounts of relational data and  select a subset of records. This widget is inspired by the song browser of iTunes.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

	use Gtk2 -init;
	use Gtk2::Ex::RecordsFilter;

	# Create a recordset
	my $recordset = [[Automobiles,Cars,Toyota,Camry],
	[Automobiles,SUV,BMW,Xi],
	[Automobiles,SUV,Toyota,Highlander],
	[Automobiles,Cars,Mitsubishi,Lancer]];

	# Create the browser object and get a ref to its widget
	my $recordsfilter = Gtk2::Ex::RecordsFilter->new($recordset);
	my $recordsfilter_widget = $recordsfilter->get_widget();

	# Create the root window
	my $window = Gtk2::Window->new;
	$window->signal_connect(destroy => sub { Gtk2->main_quit; });
	$window->set_default_size(500, 300);

	$window->add($recordsfilter_widget);	
	$window->show_all;

	Gtk2->main;  

=head1 DESCRIPTION

=head2 Methods

=over 4

=item * $browser->get_widget()

Gets the widget for the object

=item * $browser->get_selected_rows()

Gets the selected rows (in the bottom portion of the widget)

=item * $browser->get_unselected_rows()

Gets the unselected rows (in the top portion of the widget)

=item * $browser->get_selected_rowids()

Gets the ids of selected rows (in the bottom portion of the widget)

=item * $browser->get_unselected_rowids()

Gets the ids of unselected rows (in the top portion of the widget)

=back

=head1 AUTHOR

Ofey Aikon, C<< <ofey_aikon@yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-gtk2-ex-recordsfilter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2004 Ofey Aikon, All Rights Reserved.

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option) any
later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU Library General Public License for more
details.

You should have received a copy of the GNU Library General Public License along
with this library; if not, write to the Free Software Foundation, Inc., 59
Temple Place - Suite 330, Boston, MA  02111-1307  USA.

=cut

use strict;
use warnings;
use Gtk2;
use constant TRUE => 1;
use constant FALSE => !TRUE;

# Takes an array of arrays as the input. ( A set or relational records )
# The widget can be used to select a subset of these records (into a selection list)
# The methods get_selected_rows and get_unselected_rows can be used
# to view the selection (/unselection) at any point.

# 'Selected' portion is referred to as the 'RIGHT' side (bottom)
# 'Unselected' portion is referred to as the 'LEFT' side (top)
sub new {
	my ($class, $recordset) = @_;
	my $self  = {};
	$self->{ALL_ROWS_ARRAY} = $recordset;
	$self->{CURRENT_SELECTED_COLUMN} = -1;
	$self->{CURRENT_SELECTION}->{LEFT} = undef; # Which treeview is in focus ?
	$self->{CURRENT_SELECTION}->{RIGHT} = undef;
	$self->{ALL_ROWS_HASH} = undef;
	$self->{COLUMN_FIELD_INDEX} = undef;
	$self->{ROWS_INDEX}->{LEFT} = undef;
	$self->{ROWS_INDEX}->{RIGHT} = undef;
	$self->{DATA_COLUMN_COUNT} = undef; # Total number of columns
	$self->{DATA_ROW_COUNT} = undef;
	$self->{DATA_HASH}->{LEFT} = undef; # Tree data structure
	$self->{DATA_HASH}->{RIGHT} = undef;
	$self->{TREEVIEWS}->{LEFT} = [];
	$self->{TREEVIEWS}->{RIGHT} = [];
	$self->{TREEVIEW_LISTS}->{RIGHT} = [];
	$self->{TREEVIEW_LISTS}->{LEFT} = [];
	$self->{TREEVIEW_PANEL}->{LEFT} = undef;
	$self->{TREEVIEW_PANEL}->{RIGHT} = undef;
	$self->{DOWN_BUTTON} = undef;
	$self->{UP_BUTTON} = undef;
	bless ($self, $class);
	$self->_set_data($recordset);
	return $self;
}

# This method gets called everytime a treeview is clicked ('changed' signal)
# All the 'child' treeviews are reset by this method
sub _reset_lists {
	my ($self, $left_or_right, $selectedcolumn, $selectedindices) = @_;

	# Sanity check! If nothing is selected, then return
	return unless ($#{@$selectedindices} >= 0);

	my	@selectedentries = map { $self->{TREEVIEW_LISTS}->{$left_or_right}->[$selectedcolumn]->[$_] } @$selectedindices;
	$self->{CURRENT_SELECTED_COLUMN} = $selectedcolumn;
	$self->{CURRENT_SELECTION}->{$left_or_right}->[$selectedcolumn] = \@selectedentries;
	
	# Reset the lists for all 'child' treeviews. The parents (including myself) can stay as it is.

	$self->_hash_to_lists_using_selection($left_or_right, $selectedcolumn);		
	

	# Reset the model of all 'child' treeviews

	for (my $i=$selectedcolumn+1; $i<$self->{DATA_COLUMN_COUNT}; $i++) {	
		$self->_populate_model($left_or_right, $i);
	}

	# Remove from the CURRENT_SELECTION if unfocused
	for (my $i=0; $i<$self->{DATA_COLUMN_COUNT}; $i++) {	
		my ($focusrow, $focuscol) = $self->{TREEVIEWS}->{$left_or_right}->[$i]->get_cursor();
		$self->{CURRENT_SELECTION}->{$left_or_right}->[$i] = undef unless ($focusrow);
	}		
}

# Each panel is just an hbox with required number of treeviews.
# Each treeview uses a ListStore (not a TreeStore)
sub _create_panel {
	my ($self, $left_or_right) = @_;
	my $hbox = Gtk2::HBox->new (FALSE, 1);
	for (my $i=0; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		my $treeview = _create_treeview();
		
		# Create new variables. Won't work inside the signal otherwise
		my $columnid = $i;
		my $side = $left_or_right;
		
		$treeview->get_selection->signal_connect('changed' => 
			sub {
				my ($selection) = @_;
				my @selected_paths = $selection->get_selected_rows;
				my @selected_indices = map { ($_->get_indices)[0] } @selected_paths;
				$self->_reset_lists($side, $columnid, \@selected_indices);
			}
		);	
		$self->{TREEVIEWS}->{$left_or_right}->[$i] = $treeview;
		my $scrolledwindow = Gtk2::ScrolledWindow->new;
		$scrolledwindow->set_shadow_type ('etched-in');
		$scrolledwindow->set_policy ('automatic', 'automatic');
		$scrolledwindow->add ($treeview);	
		$hbox->pack_start($scrolledwindow, TRUE, TRUE, 0);
	}
	return $hbox;

}

sub _create_treeview {
	my $model = Gtk2::ListStore->new (qw/Glib::String/);
	my $treeview = Gtk2::TreeView->new_with_model($model);
	my $renderer = Gtk2::CellRendererText->new;
	my $COLUMN_NUMBER = 0;
	$renderer->set_data (column => $COLUMN_NUMBER);
	$treeview->insert_column_with_attributes (-1, "Header", $renderer, text => $COLUMN_NUMBER);
	$treeview->set_headers_visible(FALSE);
	$treeview->get_selection->set_mode ('multiple');
	return $treeview;
}

# Populate entries into a specified treeview
# This gets called whenever a treeview has to be reset
# Typically called from inside the _reset_lists method
sub _populate_model {
	my ($self, $left_or_right, $treeview_number) = @_;
	my $model = $self->{TREEVIEWS}->{$left_or_right}->[$treeview_number]->get_model();
	my $list = $self->{TREEVIEW_LISTS}->{$left_or_right}->[$treeview_number];
	$model->clear;
	my $COLUMN_NUMBER = 0;
	foreach my $entry (@$list) {
		my $iter = $model->append;
		$model->set ($iter, $COLUMN_NUMBER, $entry);
	}	
}


# This method will convert the hash datastructure into lists for 
# displaying inside the treeview. Current selection must be known inorder
# to display all the treeviews on the list correctly.
sub _hash_to_lists_using_selection {
	my ($self, $left_or_right, $selectedcolumn) = @_;

	my $currentlist = $self->{TREEVIEW_LISTS}->{$left_or_right}->[$selectedcolumn];

	# All the 'child' columns are nullified
	for (my $i=$selectedcolumn; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		$self->{TREEVIEW_LISTS}->{$left_or_right}->[$i] = undef;
	}
	
	# Call the recursive procedure to populate the 'child' columns
	$self->_extract_keys ($left_or_right, $self->{DATA_HASH}->{$left_or_right}, 0, $selectedcolumn);
		
	# Remove duplicate entries from each list
	foreach my $treeview_list(@{$self->{TREEVIEW_LISTS}->{$left_or_right}}) {
		$treeview_list = _purify_array($treeview_list);
	}

	my $newlist = $self->{TREEVIEW_LISTS}->{$left_or_right}->[$selectedcolumn];

	# This portion is required for the following reason
	# If all the children of a parent get moved, the parent 'may' not realise this
	# The parent will still stay around because we call _populate_model on only the 'child' treeviews
	# The parent has to be explicitly repopulated to account for this
	# Whenever the parent treeview is focussed, the $currentlist and $newlist will be different
	#   if all the child rows are gone
	if ($currentlist and $newlist) {

		unless (_compare_arrays($currentlist, $newlist)) {
			$self->_populate_model($left_or_right, $selectedcolumn);
		}
	}

}

# Utility method. Just compares two arrays serially
sub _compare_arrays {
	my ($a, $b) = @_;
	return FALSE if ($#{@$a} != $#{@$b});
	for (my $i=0; $i<=$#{@$a}; $i++) {
		return FALSE if ($a->[$i] ne $b->[$i]);
	}
	return TRUE;
}

# Utility method. Make the array a unique list. Remove all duplicate entries
sub _purify_array {
	my ($array) = @_;
	my %hash = map {$_, 1} @$array;
	my @a = keys %hash;
	@a = sort @a;
	return \@a;
}

# This is the core recursive method that populates the 'child' columns
sub _extract_keys {
	my ($self, $left_or_right, $hash, $thiscolumn, $selectedcolumn) = @_;
	
	# Here is the termination criteria for the recursion
	return unless ($thiscolumn < $self->{DATA_COLUMN_COUNT});

	my $lists = $self->{TREEVIEW_LISTS}->{$left_or_right};		

	my $selecteditems = $self->{CURRENT_SELECTION}->{$left_or_right}->[$thiscolumn];		

	# Convert to a hash for easier search
	my %selecteditemshash;
	foreach my $selecteditem (@$selecteditems) {
		$selecteditemshash{$selecteditem} = 1 unless (!$selecteditem);
	}

	# Continue for each key in the hash
	foreach my $key (keys %$hash) {		
		push @{$lists->[$thiscolumn]}, $key;
		if ($thiscolumn <= $selectedcolumn) {
			if (%selecteditemshash) {
				next unless $selecteditemshash{$key};
			}
		}
		
		# Now continue to the next level of recursion
		my $nextcolumn = $thiscolumn + 1;
		$self->_extract_keys ($left_or_right, $hash->{$key}, $nextcolumn, $selectedcolumn);		
	}
}

# Utility method
# Given two lists, returns a list with the common elements.
sub _array_intersection {
	my ($a, $b) = @_;
	my %ahash = map {$_, 1} @$a;
	my %bhash = map {$_, 1} @$b;
	my %chash;
	foreach my $key (keys %ahash) {
		$chash{$key} = 1 if 	($bhash{$key});
	}
	foreach my $key (keys %bhash) {
		$chash{$key} = 1 if 	($ahash{$key});
	}
	my @c = keys %chash;
	return \@c;
}

# For a given column, return all the linenumbers that contain 
# the specified set ot fields. 
# This is required for partitioning the lists into 'selected' and 'unselected'
sub _locate {
	my ($self, $left_or_right, $column) = @_;
	
	# The $linenumbers will get reduced using the _array_intersection()
	# Initialize with all line numnbers
	my $linenumbers;
	for (my $i=0; $i<$self->{DATA_ROW_COUNT}; $i++) {
		push @$linenumbers, $i;
	}

	for (my $i=0; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		my $selection = $self->{CURRENT_SELECTION}->{$left_or_right}->[$i];
		
		# Get the linenumbers that contain this particular field-column
		my $theselines;
		foreach my $field (@$selection) {
			push @$theselines, @{$self->{COLUMN_FIELD_INDEX}->[$i]->{$field}};
		}
		
		# Now intersect it with the previous set of linenumbers
		# And so on keep reducing this set for evey treeview (column)
		if ($#{@$theselines} >= 0) {
			$linenumbers = _array_intersection($linenumbers, $theselines);
		}
	}
	return $linenumbers;
}

# Rebuild the ROW_INDEX for both sides. Move the $linenumbers from one INDEX to the other
sub _move_from_to {
	my ($self, $linenumbers, $from_left_or_right, $to_left_or_right) = @_;
	
	# Convert to hashes for easier search
	my %fromhash = map {$_, 1} @{$self->{ROWS_INDEX}->{$from_left_or_right}};
	my %tohash = map {$_, 1} @{$self->{ROWS_INDEX}->{$to_left_or_right}};
	
	foreach my $linenumber (@$linenumbers) {
		delete $fromhash{$linenumber};
		$tohash{$linenumber} = 1;
	}
	my @from = keys %fromhash;
	my @to = keys %tohash;
	$self->{ROWS_INDEX}->{$from_left_or_right} = \@from;
	$self->{ROWS_INDEX}->{$to_left_or_right} = \@to;
}

# Flat dataset (array of arrays) has to be converted into a hierarchical tree
# Recursion once again !!
sub _flat_to_hash {
	my ($self, $rownumbers) = @_;
	my $hash = {};
	foreach my $rownumber(@$rownumbers) {
		my $sub_hash = $hash;
		my $row = $self->{ALL_ROWS_HASH}->{$rownumber};
		for (my $i=0; $i<=$#{@$row}; $i++) {
			if (!exists $sub_hash->{$row->[$i]}) {
				if ($i<$self->{DATA_COLUMN_COUNT}-1) {
					$sub_hash->{$row->[$i]} = {};
				} else {
					$sub_hash->{$row->[$i]} = 1;
				}
			}
			$sub_hash = $sub_hash->{$row->[$i]};						
		}
	}
	return $hash;
}

# One time affair. Prepare the INDEX for later use
sub _process_recordset {
	my ($self, $recordset) = @_;
	my $columncount = $#{@{$recordset->[0]}} + 1;
	$self->{DATA_COLUMN_COUNT} = $columncount;
	my $linecount = 0;
	foreach my $record (@$recordset) {
		$self->{ALL_ROWS_HASH}->{$linecount} = $record;
		for (my $i=0; $i<=$#{@$record}; $i++) {
			push @{$self->{COLUMN_FIELD_INDEX}->[$i]->{$record->[$i]}}, $linecount;
		}
		$linecount++;
	}
	$self->{DATA_ROW_COUNT} = $linecount;	
}

# Utility method. Removes a given set of entries from an array
sub _remove_from_array {
	my ($array, $entries) = @_;
	my %hash = map {$_, 1} @$array;
	foreach my $entry (@$entries) {
		delete $hash{$entry};
	}
	@$array = keys %hash;
	return $array;
}

# Once the INDEXes are rebuilt, then rebuild the HASHes and the LISTs
sub _recreate_hashes {
	my ($self) = @_;
	$self->{DATA_HASH}->{LEFT} = $self->_flat_to_hash($self->{ROWS_INDEX}->{LEFT});
	$self->{DATA_HASH}->{RIGHT} = $self->_flat_to_hash($self->{ROWS_INDEX}->{RIGHT});
	$self->_hash_to_lists_using_selection('LEFT', $self->{CURRENT_SELECTED_COLUMN});
	$self->_hash_to_lists_using_selection('RIGHT', $self->{CURRENT_SELECTED_COLUMN});
}

# You know what this is for !
sub _create_buttons {
	my ($self) = @_;

	my $buttonlabel;
	$self->{DOWN_BUTTON} = Gtk2::Button->new;
	$buttonlabel = Gtk2::HBox->new (FALSE, 0);
	$buttonlabel->pack_start (Gtk2::Label->new(' Add to Selection '), TRUE, TRUE, 0);
	$buttonlabel->pack_start (Gtk2::Image->new_from_stock ('gtk-go-down', 'GTK_ICON_SIZE_BUTTON'), FALSE, FALSE, 0);
	$self->{DOWN_BUTTON}->add($buttonlabel);
	
	$self->{UP_BUTTON} = Gtk2::Button->new;
	$buttonlabel = Gtk2::HBox->new (FALSE, 0);
	$buttonlabel->pack_start (Gtk2::Image->new_from_stock ('gtk-go-up', 'GTK_ICON_SIZE_BUTTON'), FALSE, FALSE, 0);
	$buttonlabel->pack_start (Gtk2::Label->new(' Remove from Selection '), TRUE, TRUE, 0);
	$self->{UP_BUTTON}->add($buttonlabel);

	$self->{DOWN_BUTTON}->signal_connect (clicked => 
		sub {
			$self->_move_and_rebuild_from_to('LEFT', 'RIGHT');
		}
	);
	
	$self->{UP_BUTTON}->signal_connect (clicked => 
		sub {
			$self->_move_and_rebuild_from_to('RIGHT', 'LEFT');
		}
	);
}

# This method is responsible for doing the actual partition into 'selected' and 'unselected'
sub _move_and_rebuild_from_to {
	my ($self, $from_left_or_right, $to_left_or_right) = @_;
	
	# Sanity check! Return if no treeview is selected (focused)
	return unless ($self->{CURRENT_SELECTED_COLUMN} >=0);
	
	# First _locate the linenumbers to be moved based on the current selection
	my $linenumbers_to_move = $self->_locate($from_left_or_right,$self->{CURRENT_SELECTED_COLUMN});
	
	# Rebuild the ROW_INDEXes for the movement
	$self->_move_from_to($linenumbers_to_move, $from_left_or_right, $to_left_or_right);

	# Recreate the DATA_HASHes for the movement
	$self->_recreate_hashes();

	$self->{TREEVIEW_LISTS}->{$from_left_or_right}->[$self->{CURRENT_SELECTED_COLUMN}] = 
		_remove_from_array($self->{TREEVIEW_LISTS}->{$from_left_or_right}->[$self->{CURRENT_SELECTED_COLUMN}], $self->{CURRENT_SELECTION}->{$from_left_or_right}->[$self->{CURRENT_SELECTED_COLUMN}]);
	$self->{TREEVIEW_LISTS}->{$from_left_or_right}->[$self->{CURRENT_SELECTED_COLUMN}] =
		_purify_array($self->{TREEVIEW_LISTS}->{$from_left_or_right}->[$self->{CURRENT_SELECTED_COLUMN}]);

	# On the FROM side, re-populate only the child treeviews
	for (my $i=$self->{CURRENT_SELECTED_COLUMN}; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		$self->_populate_model($from_left_or_right, $i);
	}
	
	# On the TO side, re-populate all the treeviews
	for (my $i=0; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		$self->_populate_model($to_left_or_right, $i);		
	}	
}

# Show everything to start with
sub _initialize {
	my ($self) = @_;
	
	# Display everything on the LEFT side to start with
	for (my $i=0; $i<$self->{DATA_ROW_COUNT}; $i++) {
		push @{$self->{ROWS_INDEX}->{LEFT}}, $i;
	}
	$self->{DATA_HASH}->{LEFT} = $self->_flat_to_hash($self->{ROWS_INDEX}->{LEFT});
	
	# Prepare LEFT and RIGHT sides for display
	$self->_hash_to_lists_using_selection('LEFT', 0);
	$self->_hash_to_lists_using_selection('RIGHT', 0);

	# Create the LEFT and RIGHT panels
	$self->{TREEVIEW_PANEL}->{LEFT} = $self->_create_panel('LEFT');
	$self->{TREEVIEW_PANEL}->{RIGHT} = $self->_create_panel('RIGHT');

	# Now populate all the treeviews
	for (my $i=0; $i<$self->{DATA_COLUMN_COUNT}; $i++) {
		$self->_populate_model('LEFT', $i);
		$self->_populate_model('RIGHT', $i);
	}
}

sub _set_data {
	my ($self, $recordset) = @_;
	$self->_process_recordset($recordset);
	$self->_initialize();
	$self->_create_buttons();
}

# Public method to get the widget itself
sub get_widget {
	my ($self) = @_;
	
	my $buttonbox = Gtk2::HBox->new(TRUE, 0);
	$buttonbox->pack_start (Gtk2::Label->new, TRUE, TRUE, 0);
	$buttonbox->pack_start($self->{UP_BUTTON}, FALSE, TRUE, 0);
	$buttonbox->pack_start($self->{DOWN_BUTTON}, FALSE, TRUE, 0);
	$buttonbox->pack_start (Gtk2::Label->new, TRUE, TRUE, 0);
	
	my $vbox = Gtk2::VBox->new (FALSE, 1);
	$vbox->pack_start($self->{TREEVIEW_PANEL}->{LEFT}, TRUE, TRUE, 0);
	$vbox->pack_start($buttonbox, FALSE, TRUE, 0);
	$vbox->pack_start($self->{TREEVIEW_PANEL}->{RIGHT}, TRUE, TRUE, 0);
	return $vbox;
}

# Public method to get the 'selected' portion
sub get_selected_rowids {
	my ($self) = @_;
	return $self->{ROWS_INDEX}->{RIGHT};
}

# Public method to get the 'unselected' portion
sub get_unselected_rowids {
	my ($self) = @_;
	return $self->{ROWS_INDEX}->{LEFT};
}

# Public method to get the 'selected' portion
sub get_selected_rows {
	my ($self) = @_;
	my @rows = map { $self->{ALL_ROWS_ARRAY}->[$_] } @{$self->{ROWS_INDEX}->{RIGHT}};
	return \@rows;
}

# Public method to get the 'unselected' portion
sub get_unselected_rows {
	my ($self) = @_;
	my @rows = map { $self->{ALL_ROWS_ARRAY}->[$_] } @{$self->{ROWS_INDEX}->{LEFT}};
	return \@rows;
}

1;

__END__
