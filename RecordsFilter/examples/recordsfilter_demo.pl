use Gtk2::Ex::RecordsFilter;
use strict;
use warnings;
use Data::Dumper;
use Gtk2 -init;
use constant TRUE => 1;
use constant FALSE => !TRUE;

$| = 1; # Set output to flush directly (for troubleshooting)

# Read the __DATA__ into an array of arrays. (Relational data)
my $recordset = [];
while(<DATA>) {
	next if /^#/;
	chomp;
	my (@columns) = split /\,/;
	push @$recordset, \@columns;
}

# Create the root window
my $window = Gtk2::Window->new;
$window->signal_connect(destroy => sub { Gtk2->main_quit; });
$window->set_default_size(500, 300);

# Create the browser and get a ref to its widget
my $recordsfilter = Gtk2::Ex::RecordsFilter->new($recordset);
my $recordsfilter_widget = $recordsfilter->get_widget();

# Create two buttons just to display the selections
my $apply_button = Gtk2::Button->new_from_stock('gtk-apply');
my $cancel_button = Gtk2::Button->new_from_stock('gtk-cancel');

$apply_button->signal_connect (clicked => 
	sub {
		print Dumper $recordsfilter->get_selected_rows();
	}
);

$cancel_button->signal_connect (clicked => 
	sub {
		Gtk2->main_quit;
	}
);

# Pack the widgets
my $buttonbox = Gtk2::HBox->new(TRUE, 0);
$buttonbox->pack_start (Gtk2::Label->new, FALSE, FALSE, 0);
$buttonbox->pack_start($apply_button, TRUE, TRUE, 0);
$buttonbox->pack_start($cancel_button, TRUE, TRUE, 0);
$buttonbox->pack_start (Gtk2::Label->new, FALSE, FALSE, 0);

my $vbox = Gtk2::VBox->new (FALSE, 0);
$vbox->pack_start ($recordsfilter_widget, TRUE, TRUE, 0);
$vbox->pack_start ($buttonbox, FALSE, FALSE, 0);

$window->add($vbox);	
$window->show_all;

Gtk2->main;

__DATA__
Food,Natural,Fruits,Apple
Food,Natural,Fruits,Pear
Food,Natural,Vegetables,Cabbage
Food,Natural,Vegetables,Potato
Food,Natural,Vegetables,Garlic
Food,Spices,Pungent,Garlic
Food,Roots,Pungent,Garlic
Food,Prepared,Chocolate,Ferrero
Food,Prepared,Chocolate,Mars
Food,Prepared,Bread,French
Food,Prepared,Bread,Italian
Food,Prepared,Bread,Garlic
Automobiles,Cars,BMW,350i
Automobiles,Cars,BMW,530i
Automobiles,Cars,Toyota,Camry
Automobiles,Cars,Toyota,Corolla
Automobiles,SUV,BMW,Xi
Automobiles,SUV,Toyota,Highlander
Automobiles,SUV,Mitsubishi,Pajero
Automobiles,Cars,Mitsubishi,Lancer
ToyCars,SUV,BMW,Xi