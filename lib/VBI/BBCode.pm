package VBI::BBCode;

use warnings;
use strict;

use Data::Dumper;

use parent 'Parse::BBCode';

sub new {
    my ($class, $posts) = @_;

    # Totally evil.  Parse::BBCode is written such that I can't just
    # override escape_html function in my subclass, because it does this
    # silly thing for some reason:
    #
    #     my $escape = \&Parse::BBCode::escape_html;
    #
    # So just reach into their symbol table and replace it with my less
    # strict one.
    {
        no warnings 'redefine';

        *Parse::BBCode::escape_html = \&escape_html_less_strict;
    }

    # These are the tags I'm overriding from Parse::BBCode or adding
    my %tags = (
        'quote'    => { code => \&do_quote,    parse => 1, class => 'block', },
        'attach'   => { code => \&do_attach,   parse => 1, class => 'block', },
        'flipthis' => { code => \&do_flipthis, parse => 1, class => 'block', },
        'fliptext' => { code => \&do_fliptext, parse => 1, class => 'block', },
        'youtube'  => { code => \&do_youtube,  parse => 1, class => 'block', },
        'video'    => { code => \&do_video,    parse => 1, class => 'block', },
        '-'        => { code => \&do_strike,   parse => 1, class => 'inline', },
        'font'     => { code => \&do_font,     parse => 1, class => 'inline', },
        'color'    => { code => \&do_color,    parse => 1, class => 'inline', },
        'spoiler'  => { code => \&do_spoiler,  parse => 1, class => 'inline', },
        'spoilerbox' => { code => \&do_spoilerbox, parse => 1, class => 'block', },
        'code'       => { code => \&do_code,       parse => 1, class => 'block', },
    );

    my $smilies = $class->get_smilies();

    my $self = $class->SUPER::new({
        close_open_tags => 1,
        tags => {
            # load the default tags
            Parse::BBCode::HTML->defaults,

            # add/override tags
            %tags
        },
        smileys => {
            base_url => '../../smileys/',
            icons => $smilies,
            format => '<img src="%s" alt="%s">',
        },
        attribute_parser => \&parse_attributes,
    });

    $self->{'posts'} = $posts;

    return $self;
}

sub find_attachment {
    my ($posts, $attachment_id) = @_;

    foreach my $post (@$posts) {
        my $attachments = $post->{'attachments'};

        if(my ($matched) = grep { $_->{'attachmentid'} eq $attachment_id } @$attachments) {
            return $matched;
        }
    }
}

# Examples:
#    [quote]foo[/quote] - no attribution
#    [quote=Bob]foo[/quote] - attributed to Bob
#    [quote=Bob;5678[/quote] - attributed to Bob, with user id specified
#
# I'm just stripping the user id below because forum members won't have
# profile pages or anything in the archive.
sub do_quote {
    my ($parser, $attr, $content) = @_;
    my $title = 'Quote';
    if ($attr) {
        $attr =~ s/;\d+$//; # remove user id from end of attr
        $title = "Originally posted by <strong>" . Parse::BBCode::escape_html($attr) . "</strong>";
    }
    return qq{
        <div class="bbcode_quote_header">$title:
        <div class="bbcode_quote_body">$$content</div></div>
    };
}

# Example: [ATTACH=CONFIG]29010[/ATTACH]
# TODO: Probably have to examine attachment->extension and
# render things like zips differently :( argh
sub do_attach {
    my ($parser, $attr, $content) = @_;
    if ($attr) {
        # is it always "CONFIG"???
    }
    my $posts = $parser->{'posts'};
    my $a = find_attachment($posts, $$content);
    # Todo put the image dimensions in the html, and maybe do thumbnail?
    return "[Unable to find specified attachment]" unless $a;
    my $filename = $a->{'filename'};
    return qq{
        <div class="attached_image">
            <img src="../../attachments/$filename">
        </div>
    };
}

# Example: [flipthis]<some image url>[/flipthis]
sub do_flipthis {
    my ($parser, $attr, $content) = @_;
    return qq{
        (╯°□°)╯︵<img src="$$content" style=" -moz-transform: rotate(180deg); -o-transform: rotate(180deg); -webkit-transform: rotate(180deg); transform: rotate(180deg); filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2); " />
    };
}

# Example: [fliptext]wat[/fliptext]
sub do_fliptext {
    my ($parser, $attr, $content) = @_;
    return qq{
        (╯°□°)╯︵<span style=" -moz-transform: rotate(180deg); -o-transform: rotate(180deg); -webkit-transform: rotate(180deg); -ms-transform: rotate(180deg); transform: rotate(180deg); display: inline-block; ">$$content</span>
    };
}

# Example: [youtube]q-wGMlSuX_c[/youtube]
sub do_youtube {
    my ($parser, $attr, $content) = @_;
    return qq{
        <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$$content?rel=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
    };
}

# Example: [video=youtube;q-wGMlSuX_c]https://www.youtube.com/watch?v=OFsN97cxI-c[/youtube]
# I have no idea what other providers may have been recogized but there were
# a bunch of references to shockwave flash in the original code.  Right now
# only supports youtube.
sub do_video {
    my ($parser, $attr, $content) = @_;
    if(!$attr) {
        return "Sorry, don't know how to play this video :(<br>$$content";
    }

    if($attr =~ /^youtube;/i) {
        $attr =~ s/^youtube;//;
    }
    else {
        return "Sorry, don't know how to play this video :(<br>$$content";
    }
    return qq{
        <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$attr?rel=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
        <iframe class="ytplayer" type="text/html" width="560" height="315" src="https://www.youtube.com/embed/$attr?autoplay=0" frameborder="0" allowfullscreen></iframe>
    };
}

# Example: [-]foo[/-]
sub do_strike {
    my ($parser, $attr, $content) = @_;
    return qq{
        <s>$$content</s>
    };
}

# Example: [FONT=verdana]text[/font]
sub do_font {
    my ($parser, $attr, $content) = @_;
    return qq{
        <span style="font-face: $attr;">$$content</span>
    };
}

# Example: [COLOR=#FFFFFF]text[/color]
sub do_color {
    my ($parser, $attr, $content) = @_;
    return qq{
        <span style="color: $attr;">$$content</span>
    };
}

sub do_spoiler {
    my ($parser, $attr, $content) = @_;
    return qq{
        <span style="background-color: #000; color: #000;" onmouseover="this.style.color='#FFFFFF';" onmouseout="this.style.color='#000000'">$$content</span>
    };
}

sub do_spoilerbox {
    my ($parser, $attr, $content) = @_;
    return qq{
        <blockquote><small>spoiler:</small><div style="color: black; background-color: black;" onmouseover="this.style.color='white';" onmouseout="this.style.color='black'">$$content</div></blockquote>
    };
}

sub do_code {
    my ($parser, $attr, $content) = @_;
    $$content =~ s/<br>//g;
    my $title = 'Code';
    if ($attr) {
        $title = Parse::BBCode::escape_html($attr);
    }
    return qq{
        <div class="bbcode_code_header">$title:
        <div class="bbcode_code_body"><pre>$$content</pre></div></div>
    };
}


sub get_smilies {
    my $class = shift;

    return {
        '.('           => '1i_frown.gif',
        ':tinfoil:'    => 'emot-tinfoil.gif',
        ':suicide:'    => 'emot-suicide.gif',
        ':awesome:'    => 'emot-awesom.gif',
        ':neckbeard:'  => 'emot-neckbeard.gif',
        ':colbert:'    => 'emot-colbert.gif',
        ':hist101:'    => 'emot-hist101.gif',
        ':eng101:'     => 'emot-eng101-good.gif',
        ':rant:'       => 'emot-rant-massassi.gif',
        ':tfti:'       => 'tfti.png',
        ':master:'     => 'emot-master.gif',
        ':nonono:'     => 'nonono2.gif',
        ':huh:'        => 'awesome-huh.png',
        ':XD:'         => 'awesome-xd.png',
        ':carl:'       => 'carl.png',
        ':awesomelon:' => 'emot-awesomelon.gif',
        ':psylon:'     => 'emot-psylon.gif',
        ':smith:'      => 'emot-smith.gif',
        ':omg:'        => 'awesome-shock.png',
        ':downswords:' => 'emot-downswords.gif',
        ':argh:'       => 'emot-argh.gif',
        ':)'           => 'smile_new.gif',
        ':rolleyes:'   => 'rolleyes.gif',
        ':cool:'       => 'cool.gif',
        ':P'           => 'tongue.gif',
        ';)'           => 'wink.gif',
        ':D'           => 'biggrin.gif',
        ':o'           => 'emot-eek.gif',
        ':('           => 'frown.gif',
        ':eek:'        => 'eek.gif',
        ':confused:'   => 'confused_new.gif',
        ':mad:'        => 'mad_new.gif',
        ':gonk:'       => 'emot-gonk.gif',
        ':psyduck:'    => 'emot-psyduck.gif',
        ':v:'          => 'emot-v.gif',
        ':gbk:'        => '3.gif',
        ':ninja:'      => 'emot-ninja.gif',
        ':farnsworth:' => 'goodnews.gif',
    };
}

# This is a copy of the "parse_attributes" method from the parent class,
# but modified to allow spaces in attributes and to strip any `;1234`
# semi-colon followed by a number that's added to an attribute (this was
# used by vbulletin to link to the quoted-user's profile page).
#
# Example: [quote=Bob Barker;1234
sub parse_attributes {
    my ($self, %args) = @_;
    my $text = $args{text};
    my $tagname = $args{tag};
    my $attribute_quote = $self->get_attribute_quote;
    my $attr_string = '';
    my $attributes = [];
    if (
        ($self->get_direct_attribute and $$text =~ s/^(=[^\]]*)?]//)
            or
        ($$text =~ s/^( [^\]]*)?\]//)
    ) {
        my $attr = $1;
        my $end = ']';
        $attr = '' unless defined $attr;
        $attr_string = $attr;
        unless (length $attr) {
            return (1, [], $attr_string, $end);
        }
        if ($self->get_direct_attribute) {
            $attr =~ s/^=//;
        }
        if ($self->get_strict_attributes and not length $attr) {
            return (0, [], $attr_string, $end);
        }
        my @array;
        if (length($attribute_quote) == 1) {
            #if ($attr =~ s/^(?:$attribute_quote(.+?)$attribute_quote(?:\s+|$)|(.*?)(?:\s+|$))//) {
            if ($attr =~ s/^(?:$attribute_quote(.+?)$attribute_quote(?:\s+|$)|(.*?)(?:\;.*$)|(.*?)(?:\s+|$))//) {
                my $val;

                foreach my $item ($1, $2, $3) {
                    $val = $item if defined $item;
                }
                #my $val = defined $1 ? $1 : $2;
                push @array, [$val];
            }
            while ($attr =~ s/^([a-zA-Z0-9_]+)=(?:$attribute_quote(.+?)$attribute_quote(?:\s+|$)|(.*?)(?:\s+|$))//) {
                my $name = $1;
                my $val = defined $2 ? $2 : $3;
                push @array, [$name, $val];
            }
        }
        else {
            if ($attr =~ s/^(?:(["'])(.+?)\1|(.*?)(?:\s+|$))//) {
                my $val = defined $2 ? $2 : $3;
                push @array, [$val];
            }
            while ($attr =~ s/^([a-zA-Z0-9_]+)=(?:(["'])(.+?)\2|(.*?)(?:\s+|$))//) {
                my $name = $1;
                my $val = defined $3 ? $3 : $4;
                push @array, [$name, $val];
            }
        }
        if ($self->get_strict_attributes and length $attr and $attr =~ tr/ //c) {
            return (0, [], $attr_string, $end);
        }
        $attributes = [@array];
        return (1, $attributes, $attr_string, $end);
    }
    return (0, $attributes, $attr_string, '');
}

# Copied from parent, but don't escape &amp; because it breaks tons of things
# like single quotes; hopefully vbulletin already verified the input was good
# before they saved to db?
sub escape_html_less_strict {
    my ($str) = @_;
    return '' unless defined $str;
    #$str =~ s/&/&amp;/g;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&#39;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    return $str;
}

1;
