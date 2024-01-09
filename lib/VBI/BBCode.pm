package VBI::BBCode;

use warnings;
use strict;

# use Parse::BBCode;

use parent 'Parse::BBCode';

sub new {
    my ($class, $posts) = @_;

    # These are the tags I'm overloading from Parse::BBCode
    my %tags = (
        'quote'    => { code => \&do_quote,    parse => 1, class => 'block', },
        'attach'   => { code => \&do_attach,   parse => 1, class => 'block', },
        'flipthis' => { code => \&do_flipthis, parse => 1, class => 'block', },
        'fliptext' => { code => \&do_fliptext, parse => 1, class => 'block', },
        'youtube'  => { code => \&do_youtube,  parse => 1, class => 'block', },
        'video'    => { code => \&do_video,    parse => 1, class => 'block', },
        '-'        => { code => \&do_strike,   parse => 1, class => 'block', },
    );

    my $self = $class->SUPER::new({
        tags => {
            # load the default tags
            Parse::BBCode::HTML->defaults,

            # add/override tags
            %tags
        }
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
    my ($filename, $width, $height, $thumbnail_width, $thumbnail_height) = $a->{'filename'};
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
    if($attr =~ /^youtube;/i) {
        $attr =~ s/^youtube;//;
    }
    else {
        return "Sorry, don't know how to play $attr videos :(";
    }
    return qq{
        <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$attr?rel=0" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
    };
}

# Example: [-]foo[/-]
sub do_strike {
    my ($parser, $attr, $content) = @_;
    return qq{
        <s>$$content</s>
    };
}

1;
